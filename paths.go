package main

import "path/filepath"

import "os"

func getFiles(dir string) []string {
	files := []string{}

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})

	if err != nil {
		log.Error("cannot get files in '%s'", dir)
	}

	return files
}
