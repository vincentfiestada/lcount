package main

import (
	"flag"

	"github.com/vincentfiestada/captainslog/v2"
	"github.com/vincentfiestada/captainslog/v2/format"
	"github.com/vincentfiestada/captainslog/v2/levels"
)

var log = captainslog.NewLogger()

func init() {
	log.Level = levels.Debug
	log.Format = format.Minimal
}

func main() {
	log.Info("lcount v%s\n%6s", version, "----")

	flag.Parse()
	targetDirs := flag.Args()

	if len(targetDirs) < 1 {
		log.Fatal("one or more target directories are required")
	}

	totalLines := 0
	for _, dir := range targetDirs {
		files := getFiles(dir)
		linesInDir := 0
		for _, file := range files {
			lines := countLines(file)
			linesInDir += lines
		}

		totalLines += linesInDir
		log.Info("Lines in '%s': %d", dir, linesInDir)
	}

	log.Info("Total Lines of Code: %d", totalLines)
}
