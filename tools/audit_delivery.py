#!/usr/bin/env python3
"""Read-only committed MoonBit LOC/history audit (Python 3.8+, local Git only).

Counts are conservative syntactic evidence, NOT semantic meaningfulness,
originality, authorship proof, contest approval, or a replacement for review.
Only --strict enforces >=1500 production lines and >=20 distinct, nonempty
first-parent tree-changing commits. No files, refs, config, or remotes change.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

MIN_LINES = 1500
MIN_COMMITS = 20
EXCLUDED_DIRS = {"example", "examples", "test", "tests", "generated", "vendor",
                 "third_party", "_build", ".mooncakes"}
TEST_DECLARATION = re.compile(r'^\s*(?:async\s+)?test(?=\s|["{(]|$)')


def git(repo, *arguments):
    """No shell, checked status, bounded wait, bytes to preserve Git path records."""
    return subprocess.run(["git", "--no-pager", "--no-replace-objects", "-C", str(repo)] + list(arguments), check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=120).stdout


def source_exclusion(path):
    parts = path.replace("\\", "/").lower().split("/")
    name = parts[-1]
    if not name.endswith(".mbt"):
        return "generated interface" if name.endswith(".mbti") else "not .mbt"
    if any(part in EXCLUDED_DIRS for part in parts[:-1]):
        return "example/test/generated/vendor directory"
    if (name.endswith(("_test.mbt", "_wbtest.mbt")) or name in {"test.mbt", "tests.mbt"}
            or name.startswith(("test_", "wbtest_"))):
        return "test source filename"
    if name.endswith(".generated.mbt") or name.startswith("generated_"):
        return "generated source filename"
    return None


class Lexer:
    """Small comment/literal lexer, not the MoonBit compiler or a complete AST.

    Masks quoted contents, honors escapes, nested /* */ comments, // docs, and
    line-oriented #|/$| literals. Unterminated quotes/comments fail closed.
    """
    def __init__(self):
        self.depth = 0

    def clean(self, line):
        if self.depth == 0 and line.lstrip().startswith(("#|", "$|")):
            return '"literal"'
        output = []
        quote = None
        index = 0
        while index < len(line):
            pair = line[index:index + 2]
            char = line[index]
            if self.depth:
                if pair == "/*":
                    self.depth += 1
                    index += 2
                elif pair == "*/":
                    self.depth -= 1
                    index += 2
                    output.append(" ")
                else:
                    index += 1
            elif quote:
                if char == "\\":
                    index += 2
                elif char == quote:
                    quote = None
                    index += 1
                else:
                    index += 1
            elif pair == "//":
                break
            elif pair == "/*":
                self.depth += 1
                index += 2
                output.append(" ")
            elif char in {'"', "'"}:
                quote = char
                output.append('"literal"')
                index += 1
            else:
                output.append(char)
                index += 1
        if quote:
            raise ValueError("Unterminated quoted literal; cannot conservatively audit")
        return "".join(output).strip()


def count_source(text):
    """Exclude whole ///| blocks containing any declaration-like test line.

    Mixed production/test blocks are deliberately undercounted. Every remaining
    nonblank, noncomment line counts, including structural punctuation. Tests'
    helpers in production blocks cannot be inferred
    semantically. Generated content without a naming marker needs manual review.
    """
    lexer = Lexer()
    blocks = [[]]
    lines = text.splitlines()
    blank = 0
    for line in lines:
        if lexer.depth == 0 and line.lstrip().startswith("///|"):
            blank += 1
            blocks.append([])
        else:
            cleaned = lexer.clean(line)
            blocks[-1].append(cleaned)
            if not cleaned:
                blank += 1
    if lexer.depth:
        raise ValueError("Unterminated block comment; cannot conservatively audit")
    substantive = test_lines = test_blocks = 0
    for block in blocks:
        is_test = any(TEST_DECLARATION.match(line) for line in block)
        if is_test:
            test_blocks += 1
        for line in block:
            if not line:
                continue
            if is_test:
                test_lines += 1
            else:
                substantive += 1
    return {"physical_lines": len(lines), "substantive_lines": substantive,
            "blank_or_comment_lines": blank,
            "inline_test_blocks": test_blocks, "inline_test_substantive_lines": test_lines}


def parse_numstat(data):
    """--no-renames -z: tab-delimited numbers, then an opaque NUL-ended path."""
    records = []
    for record in data.split(b"\0"):
        if not record:
            continue
        added, deleted, path = record.split(b"\t", 2)
        records.append({"path": path.decode("utf-8", "surrogateescape"),
                        "added": None if added == b"-" else int(added),
                        "deleted": None if deleted == b"-" else int(deleted)})
    return records


def history_audit(repo, revision):
    commits = git(repo, "rev-list", "--reverse", "--topo-order", revision).decode("ascii").splitlines()
    rows = []
    trees_by_commit = {}
    first_tree_occurrence = {}
    for commit in commits:
        fields = git(repo, "show", "-s", "--format=%H%x00%T%x00%P%x00%an%x00%ae%x00%cn%x00%ce%x00%aI%x00%s",
                     commit).decode("utf-8", "replace").rstrip("\n").split("\0")
        if len(fields) != 9:
            raise ValueError("Unexpected Git commit metadata")
        sha, tree, parent_text, author, email, committer, committer_email, date, subject = fields
        parents = parent_text.split()
        if parents:
            stats = parse_numstat(git(repo, "diff", "--numstat", "-z", "--no-renames",
                                      "--no-ext-diff", "--no-textconv", "--diff-algorithm=myers",
                                      "--no-indent-heuristic", "--ignore-submodules=none", parents[0], sha, "--"))
            nonempty = tree != trees_by_commit[parents[0]]
        else:
            stats = parse_numstat(git(repo, "diff-tree", "--root", "-r", "--no-commit-id", "--numstat", "-z",
                                      "--no-renames", "--no-ext-diff", "--no-textconv", "--diff-algorithm=myers",
                                      "--no-indent-heuristic", "--ignore-submodules=none", sha, "--"))
            nonempty = bool(stats)
        repeated_of = first_tree_occurrence.get(tree)
        row = {"commit": sha, "tree": tree, "parents": parents,
               "author": {"name": author, "email": email},
               "committer": {"name": committer, "email": committer_email},
               "author_date": date, "subject": subject,
               "nonempty_first_parent_tree_change": nonempty,
               "repeated_tree_of": repeated_of,
               "distinct_nonempty_tree_change": nonempty and repeated_of is None,
               "changed_files": len(stats),
               "added_lines": sum(item["added"] or 0 for item in stats),
               "deleted_lines": sum(item["deleted"] or 0 for item in stats),
               "binary_files": sum(item["added"] is None for item in stats), "files": stats}
        rows.append(row)
        trees_by_commit[sha] = tree
        first_tree_occurrence.setdefault(tree, sha)
    authors = sorted({(row["author"]["name"], row["author"]["email"]) for row in rows})
    return {"commits": rows, "commit_count": len(rows),
            "nonempty_commit_count": sum(row["nonempty_first_parent_tree_change"] for row in rows),
            "unique_tree_count": len(first_tree_occurrence),
            "repeated_tree_commit_count": sum(row["repeated_tree_of"] is not None for row in rows),
            "distinct_nonempty_commit_count": sum(row["distinct_nonempty_tree_change"] for row in rows),
            "authors": [{"name": name, "email": email} for name, email in authors]}


def threshold_observations(lines, commits):
    return {"minimum_substantive_lines": MIN_LINES,
            "minimum_distinct_nonempty_commits": MIN_COMMITS,
            "lines_pass": lines >= MIN_LINES, "commits_pass": commits >= MIN_COMMITS}


def audit(repo, revision="HEAD"):
    if git(repo, "rev-parse", "--is-shallow-repository").strip() == b"true":
        raise ValueError("Shallow repository cannot establish complete ancestry; no fetch is attempted")
    pinned = git(repo, "rev-parse", "--verify", "--end-of-options", revision + "^{commit}").decode("ascii").strip()
    sources = []
    excluded = []
    for record in git(repo, "ls-tree", "-r", "-z", "--full-tree", pinned).split(b"\0"):
        if not record:
            continue
        metadata, path_bytes = record.split(b"\t", 1)
        mode, kind, blob = metadata.split()
        path = path_bytes.decode("utf-8", "surrogateescape")
        if not path.lower().endswith((".mbt", ".mbti")):
            continue
        reason = source_exclusion(path)
        if kind != b"blob" or mode not in {b"100644", b"100755"}:
            reason = "not a regular tracked source blob"
        if reason:
            excluded.append({"path": path, "reason": reason})
            continue
        text = git(repo, "cat-file", "blob", blob.decode("ascii")).decode("utf-8-sig")
        counts = count_source(text)
        sources.append(dict(path=path, blob=blob.decode("ascii"), **counts))
    sources.sort(key=lambda row: row["path"])
    excluded.sort(key=lambda row: row["path"])
    history = history_audit(repo, pinned)
    total = sum(row["substantive_lines"] for row in sources)
    return {"revision": pinned, "source": {"files": sources, "excluded_files": excluded,
                                            "substantive_lines": total},
            "history": history,
            "thresholds": threshold_observations(total, history["distinct_nonempty_commit_count"]),
            "limitations": ["Committed revision only; dirty and untracked worktree files are not counted.",
                            "Syntactic conservative LOC, not a compiler/AST or semantic originality assessment.",
                            "Whole ///| blocks with declaration-like test lines are excluded, including mixed blocks.",
                            "Blank/comment-only lines are excluded; structural punctuation lines count.",
                            "Generated/vendored content without path markers and test-only helpers need manual review.",
                            "All locally reachable ancestors are listed; stats compare merge commits to first parent only.",
                            "Git replacement objects are disabled; shallow histories are rejected without fetching.",
                            "Unique nonempty trees are mechanical history evidence, not meaningful-commit certification.",
                            "Authors are Git metadata, not verified identities; binary changes have no numeric LOC.",
                            "Numstat uses fixed Myers/no-renames settings; Git attributes can affect binary classification."]}


def render_text(report):
    source, history = report["source"], report["history"]
    lines = ["Pinned committed revision: " + report["revision"], "", "Production source counts:"]
    for row in source["files"]:
        lines.append("%5d substantive / %5d physical / %3d inline-test blocks : %s" %
                     (row["substantive_lines"], row["physical_lines"], row["inline_test_blocks"], json.dumps(row["path"], ensure_ascii=True)))
    lines += ["TOTAL substantive production lines: %d" % source["substantive_lines"], "", "Excluded source/interface files:"]
    lines += [json.dumps(row["path"], ensure_ascii=True) + " : " + row["reason"] for row in source["excluded_files"]]
    lines += ["", "Every reachable commit (parent-before-child traversal):"]
    for row in history["commits"]:
        lines.append("%s author=%s subject=%s files=%d +%d -%d binary=%d nonempty=%s tree=%s repeated_of=%s" %
                     (row["commit"], json.dumps(row["author"], ensure_ascii=True), json.dumps(row["subject"], ensure_ascii=True),
                      row["changed_files"], row["added_lines"], row["deleted_lines"], row["binary_files"],
                      row["nonempty_first_parent_tree_change"], row["tree"], row["repeated_tree_of"] or "none"))
    lines += ["", "History totals: commits=%d; nonempty=%d; unique_trees=%d; repeated_trees=%d; distinct_nonempty=%d" %
              (history["commit_count"], history["nonempty_commit_count"], history["unique_tree_count"],
               history["repeated_tree_commit_count"], history["distinct_nonempty_commit_count"]),
              "Threshold observations (enforced only with --strict): " + json.dumps(report["thresholds"], sort_keys=True),
              "", "Manual semantic meaningfulness/originality review remains separate."]
    lines += ["- " + limitation for limitation in report["limitations"]]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1], help="Local repository; default script's module root")
    parser.add_argument("--revision", default="HEAD", help="Committed revision to pin, default HEAD")
    parser.add_argument("--json", action="store_true", help="Deterministic machine-readable evidence including per-commit numstat")
    parser.add_argument("--strict", action="store_true", help="Exit 1 below 1500 substantive lines or 20 distinct nonempty tree changes; default exit 0 regardless of thresholds")
    args = parser.parse_args(argv)
    try:
        report = audit(args.repo.resolve(), args.revision)
        print(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=True) if args.json else render_text(report))
        return int(args.strict and not (report["thresholds"]["lines_pass"] and report["thresholds"]["commits_pass"]))
    except subprocess.CalledProcessError as error:
        print("Local Git audit failed: " + error.stderr.decode("utf-8", "replace"), file=sys.stderr)
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print("Audit could not complete: " + str(error), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
