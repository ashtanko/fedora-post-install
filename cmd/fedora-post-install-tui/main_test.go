package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadCatalogPreservesOrderAndCompletedStatus(t *testing.T) {
	root := t.TempDir()
	markerDir := filepath.Join(root, "markers")
	if err := os.MkdirAll(filepath.Join(root, "dev"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(markerDir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"dev/node.sh", "dev/go.sh"} {
		if err := os.WriteFile(filepath.Join(root, filepath.FromSlash(path)), []byte("#!/bin/bash\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(markerPath(markerDir, "dev/node.sh"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	catalog := filepath.Join(root, "catalog.txt")
	contents := "dev|Development|Node.js|dev/node.sh\n" +
		"dev|Development|Go|dev/go.sh\n"
	if err := os.WriteFile(catalog, []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}

	categories, items, err := loadCatalog(root, catalog, markerDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(categories) != 1 || categories[0].label != "Development" {
		t.Fatalf("unexpected categories: %#v", categories)
	}
	if len(items) != 2 || items[0].label != "Node.js" || items[1].label != "Go" {
		t.Fatalf("unexpected item order: %#v", items)
	}
	if items[0].status != alreadyCompleted || items[1].status != available {
		t.Fatalf("unexpected statuses: %v, %v", items[0].status, items[1].status)
	}
}

func TestLoadCatalogRejectsUnsafeAndDuplicateScripts(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "safe.sh"), []byte("#!/bin/bash\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	tests := map[string]string{
		"parent traversal": "dev|Development|Unsafe|../unsafe.sh\n",
		"absolute path":    "dev|Development|Unsafe|/tmp/unsafe.sh\n",
		"duplicate":        "dev|Development|One|safe.sh\ndev|Development|Two|safe.sh\n",
	}
	for name, contents := range tests {
		t.Run(name, func(t *testing.T) {
			catalog := filepath.Join(t.TempDir(), "catalog.txt")
			if err := os.WriteFile(catalog, []byte(contents), 0o644); err != nil {
				t.Fatal(err)
			}
			if _, _, err := loadCatalog(root, catalog, t.TempDir()); err == nil {
				t.Fatal("expected catalog validation error")
			}
		})
	}
}

func TestSelectionAndReviewFlow(t *testing.T) {
	m := model{
		categories: []category{{id: "dev", label: "Development", indices: []int{0, 1}}},
		items:      []item{{label: "Node.js"}, {label: "Go"}},
		screen:     selectScreen,
		width:      80,
		height:     24,
	}

	updated, _ := m.handleSelectionKey("space")
	m = updated.(model)
	if !m.items[0].selected || m.selectedCount() != 1 {
		t.Fatal("space did not select the focused item")
	}
	updated, _ = m.handleSelectionKey("enter")
	m = updated.(model)
	if m.screen != reviewScreen {
		t.Fatalf("expected review screen, got %v", m.screen)
	}
	if !strings.Contains(m.reviewView(), "Node.js") {
		t.Fatal("review did not include selected item")
	}
}

func TestHelpers(t *testing.T) {
	if got := markerPath("/tmp/markers", "dev/node.sh"); got != "/tmp/markers/dev_node.sh.done" {
		t.Fatalf("unexpected marker path: %s", got)
	}
	if got := truncate("abcdefgh", 5); got != "abcd…" {
		t.Fatalf("unexpected truncation: %q", got)
	}
	if got := progressBar(1, 2, 10); !strings.Contains(got, "━━━━━") {
		t.Fatalf("unexpected progress bar: %q", got)
	}
}

func TestParseOptionsUsesFedoraDefaults(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	root := t.TempDir()

	opts, checkOnly, err := parseOptions([]string{"--root", root})
	if err != nil {
		t.Fatal(err)
	}
	if checkOnly {
		t.Fatal("default options unexpectedly enabled check-only mode")
	}
	if want := filepath.Join(home, ".cache", "fedora-setup"); opts.markerDir != want {
		t.Fatalf("unexpected default marker directory: got %q, want %q", opts.markerDir, want)
	}
	if want := filepath.Join(home, "fedora-setup.log"); opts.logFile != want {
		t.Fatalf("unexpected default log file: got %q, want %q", opts.logFile, want)
	}
}

func TestUnsupportedHostExitIsSkippedNotFailed(t *testing.T) {
	skipErr := exec.Command("/bin/bash", "-c", "exit 78").Run()
	if skipErr == nil {
		t.Fatal("expected a non-nil error for exit 78")
	}
	if !unsupportedHost(skipErr) {
		t.Error("exit 78 was not recognised as an unsupported host")
	}
	if interrupted(skipErr) {
		t.Error("exit 78 was misread as an interrupt")
	}

	failErr := exec.Command("/bin/bash", "-c", "exit 1").Run()
	if unsupportedHost(failErr) {
		t.Error("an ordinary failure was misread as an unsupported host")
	}
	if unsupportedHost(nil) {
		t.Error("success was misread as an unsupported host")
	}
}
