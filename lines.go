package main

import "io/ioutil"

import "regexp"

func countLines(path string) int {
	content, err := ioutil.ReadFile(path)
	if err != nil {
		log.Warn("cannot read contents of '%s'", path)
	}

	newLine, err := regexp.Compile("\n")
	if err != nil {
		log.Fatal("failed to compile regular expression for new line characters")
	}

	return len(newLine.FindAll(content, -1)) + 1
}
