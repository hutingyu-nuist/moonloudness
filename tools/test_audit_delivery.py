#!/usr/bin/env python3
"""Read-only audit tests; synthetic Git histories live only in OS temp dirs."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
import audit_delivery as audit


class SourceTests(unittest.TestCase):
    def test_docs_blocks_inline_tests_and_structural_punctuation(self):
        source = '''///| A production declaration
/// Documentation is not LOC.
fn value() -> Int {
  // explanation
  42 // code counts once
}

///|
/// An inline test must not contribute.
test "value" {
  assert_eq(value(), 42)
}
///|
fn other() -> Int { 7 }
'''
        result = audit.count_source(source)
        self.assertEqual(result['substantive_lines'], 4)
        self.assertEqual(result['inline_test_blocks'], 1)
        self.assertEqual(result['inline_test_substantive_lines'], 3)
        self.assertEqual(result['physical_lines'], result['substantive_lines'] +
                         result['blank_or_comment_lines'] +
                         result['inline_test_substantive_lines'])

    def test_punctuation_counts_only_outside_inline_test_blocks(self):
        source = '///|\nfn value() {\n  (\n    1\n  )\n}\n///|\ntest {\n  (\n    1\n  )\n}\n'
        result = audit.count_source(source)
        self.assertEqual(result['substantive_lines'], 5)
        self.assertEqual(result['inline_test_substantive_lines'], 5)
        self.assertEqual(result['blank_or_comment_lines'], 2)

    def test_mixed_block_is_conservatively_excluded(self):
        result = audit.count_source('fn helper() -> Int { 1 }\ntest { assert_eq(helper(), 1) }\n')
        self.assertEqual(result['substantive_lines'], 0)
        self.assertEqual(result['inline_test_substantive_lines'], 2)

    def test_test_declarations_attributes_anonymous_and_async(self):
        for declaration in ['test "name" {', 'test {', 'test\n{', 'async test "name" {']:
            source = '///|\n#cfg(target="js")\n' + declaration + '\n  1\n}\n'
            with self.subTest(declaration=declaration):
                result = audit.count_source(source)
                self.assertEqual(result['substantive_lines'], 0)
                self.assertEqual(result['inline_test_blocks'], 1)
        self.assertEqual(audit.count_source('let test_value = 1\n')['substantive_lines'], 1)

    def test_quoted_comment_markers_and_test_text_are_literals(self):
        source = '''let url = "https://example.invalid/*not a comment*/"
let escaped = "\\\" // still string"
let quote = '\\''
let name = "test { } ///|"
'''
        self.assertEqual(audit.count_source(source)['substantive_lines'], 4)
        self.assertEqual(audit.count_source(source)['inline_test_blocks'], 0)

    def test_nested_comments_and_false_separators(self):
        source = '''/* comment
///| not a separator
/* nested */ test "not code" {
*/ let x = 1 /* inline */
// only comment
/* closed */
'''
        result = audit.count_source(source)
        self.assertEqual(result['substantive_lines'], 1)
        self.assertEqual(result['inline_test_blocks'], 0)

    def test_multiline_literals_not_docs_or_tests(self):
        source = 'let text =\n  #| // literal data\n  #| test "still data"\n  $| /* literal */\n'
        result = audit.count_source(source)
        self.assertEqual(result['substantive_lines'], 4)
        self.assertEqual(result['inline_test_blocks'], 0)

    def test_unterminated_input_fails_closed(self):
        for source in ['let x = "bad\n', '/* never closed\n', "let c = '\\"]:
            with self.subTest(source=source), self.assertRaises(ValueError):
                audit.count_source(source)

    def test_source_exclusions(self):
        for path in ['examples/demo/main.mbt', 'TESTS/helpers.mbt', 'x_test.mbt',
                     'x_wbtest.mbt', 'test_helpers.mbt', 'pkg.generated.mbti',
                     'value.generated.mbt', 'generated_types.mbt', 'vendor/core.mbt']:
            with self.subTest(path=path):
                self.assertIsNotNone(audit.source_exclusion(path))
        self.assertIsNone(audit.source_exclusion('src/window.mbt'))

    def test_numstat_paths_binary_and_zero_line_changes(self):
        records = audit.parse_numstat(b'2\t1\tpath\twith\ncharacters.mbt\0-\t-\tasset.bin\0' + b'0\t0\tempty.mbt\0')
        self.assertEqual(records[0], {'path': 'path\twith\ncharacters.mbt', 'added': 2, 'deleted': 1})
        self.assertIsNone(records[1]['added'])
        self.assertEqual(records[2]['added'], 0)


class GitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='moonloudness-audit-test-')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name).resolve()
        module_root = Path(__file__).resolve().parents[1]
        self.assertNotEqual(self.repo, module_root)
        self.assertNotIn(module_root, self.repo.parents)
        self.env = os.environ.copy()
        # Fixture identity/dates and config isolation only in this subprocess env.
        self.env.update(GIT_AUTHOR_NAME='Audit Fixture', GIT_AUTHOR_EMAIL='audit@example.invalid',
                        GIT_COMMITTER_NAME='Audit Fixture', GIT_COMMITTER_EMAIL='audit@example.invalid',
                        GIT_AUTHOR_DATE='2026-10-14T00:00:00+00:00', GIT_COMMITTER_DATE='2026-10-14T00:00:00+00:00',
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        for key in ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_CONFIG_COUNT',
                    'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_COMMON_DIR']:
            self.env.pop(key, None)
        self.command('init', '--quiet')

    def command(self, *args):
        return subprocess.run(['git', '-C', str(self.repo)] + list(args), env=self.env,
                              check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=30).stdout.decode('utf-8').strip()

    def write(self, path, content):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8')

    def commit(self, subject, empty=False):
        self.command('add', '--all')
        self.command('commit', '--quiet', '--allow-empty' if empty else '--no-allow-empty', '-m', subject)
        return self.command('rev-parse', 'HEAD')

    def initial(self):
        source = '///|\nfn value() -> Int {\n  42\n}\n///|\ntest "inline" { assert_eq(value(), 42) }\n'
        self.write('lib.mbt', source)
        self.write('examples/demo/main.mbt', 'fn main { println(1) }\n')
        self.write('lib_test.mbt', 'test { assert_true(true) }\n')
        self.write('pkg.generated.mbti', 'pub fn value() -> Int\n')
        self.write('payload.bin', '\x00binary')
        return source, self.commit('initial synthetic source')

    def test_pinned_counts_ignore_dirty_and_untracked_worktree(self):
        source, first = self.initial()
        before = audit.audit(self.repo, first)
        self.write('lib.mbt', 'malformed "unterminated\n')
        self.write('untracked.mbt', 'fn pretend() -> Int { 100 }\n')
        after = audit.audit(self.repo, first)
        self.assertEqual(before, after)
        self.assertEqual(after['source']['substantive_lines'], 3)
        self.assertEqual(len(after['source']['files']), 1)
        self.assertEqual(len(after['source']['excluded_files']), 3)
        self.assertEqual(after['source']['files'][0]['inline_test_blocks'], 1)
        self.assertEqual(after['history']['commits'][0]['author']['name'], 'Audit Fixture')
        self.assertEqual(after['history']['commits'][0]['binary_files'], 1)

    def test_empty_commits_reverts_repeated_trees_and_all_authors(self):
        source, first = self.initial()
        empty = self.commit('intentional empty fixture', empty=True)
        self.env['GIT_AUTHOR_NAME'] = 'Second Audit Author'
        self.write('lib.mbt', source.replace('42', '43'))
        changed = self.commit('synthetic change')
        self.write('lib.mbt', source)
        reverted = self.commit('synthetic exact revert')
        self.commit('second empty fixture', empty=True)
        history = audit.audit(self.repo)['history']
        self.assertEqual(history['commit_count'], 5)
        self.assertEqual(history['nonempty_commit_count'], 3)
        self.assertEqual(history['unique_tree_count'], 2)
        self.assertEqual(history['repeated_tree_commit_count'], 3)
        self.assertEqual(history['distinct_nonempty_commit_count'], 2)
        self.assertEqual(len(history['authors']), 2)
        rows = {row['commit']: row for row in history['commits']}
        self.assertFalse(rows[empty]['nonempty_first_parent_tree_change'])
        self.assertEqual(rows[empty]['changed_files'], 0)
        self.assertTrue(rows[changed]['distinct_nonempty_tree_change'])
        self.assertTrue(rows[reverted]['nonempty_first_parent_tree_change'])
        self.assertEqual(rows[reverted]['repeated_tree_of'], first)
        self.assertFalse(rows[reverted]['distinct_nonempty_tree_change'])
        self.assertEqual(rows[changed]['added_lines'], 2)
        self.assertEqual(rows[changed]['deleted_lines'], 2)

    def test_empty_root_is_not_nonempty(self):
        self.commit('empty root fixture', empty=True)
        history = audit.audit(self.repo)['history']
        self.assertEqual(history['unique_tree_count'], 1)
        self.assertEqual(history['distinct_nonempty_commit_count'], 0)
        self.assertEqual(history['nonempty_commit_count'], 0)

    def test_merge_stats_are_first_parent_and_all_ancestors_listed(self):
        source, first = self.initial()
        self.command('branch', 'side')
        self.write('left.txt', 'left\n')
        left = self.commit('left branch')
        self.command('checkout', '--quiet', 'side')
        self.write('right.txt', 'right\n')
        right = self.commit('right branch')
        self.command('merge', '--quiet', '--no-ff', left, '-m', 'synthetic merge')
        history = audit.audit(self.repo)['history']
        self.assertEqual(history['commit_count'], 4)
        merge = history['commits'][-1]
        self.assertEqual(merge['parents'], [right, left])
        self.assertEqual(merge['changed_files'], 1)
        self.assertEqual(merge['files'][0]['path'], 'left.txt')
        self.assertTrue(merge['distinct_nonempty_tree_change'])

    def test_default_exit_zero_strict_failure_and_json_reproducibility(self):
        self.initial()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(audit.main(['--repo', str(self.repo), '--json']), 0)
        parsed = json.loads(output.getvalue())
        self.assertFalse(parsed['thresholds']['lines_pass'])
        self.assertFalse(parsed['thresholds']['commits_pass'])
        again = io.StringIO()
        with contextlib.redirect_stdout(again):
            self.assertEqual(audit.main(['--repo', str(self.repo), '--json', '--strict']), 1)
        self.assertEqual(output.getvalue(), again.getvalue())

    def test_invalid_revision_exit_two(self):
        self.initial()
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(audit.main(['--repo', str(self.repo), '--revision', 'missing-ref']), 2)


class ThresholdTests(unittest.TestCase):
    def test_numeric_thresholds(self):
        for lines, commits, expected in [(1500, 20, (True, True)),
                                         (1499, 20, (False, True)),
                                         (1500, 19, (True, False))]:
            observed = audit.threshold_observations(lines, commits)
            self.assertEqual((observed['lines_pass'], observed['commits_pass']), expected)

    def test_strict_boundary_without_manufacturing_twenty_history_commits(self):
        for lines_pass, commits_pass, expected in [(True, True, 0), (False, True, 1), (True, False, 1)]:
            report = {'thresholds': {'lines_pass': lines_pass, 'commits_pass': commits_pass}}
            with mock.patch.object(audit, 'audit', return_value=report), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(audit.main(['--json', '--strict']), expected)
                self.assertEqual(audit.main(['--json']), 0)


if __name__ == '__main__':
    unittest.main()
