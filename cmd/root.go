package cmd

import (
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/spf13/cobra"
)

var stdinPath string

// stdinMode hand the buffer back unchanged - for now
func stdinMode(path string) {
	_, _ = io.Copy(os.Stdout, os.Stdin)
}

func formatRepo(paths []string) error {
	return errors.New("not yet implemented")
}

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:           "bachfmt",
	Short:         "Format a repo with the project's own formatters, or the house style.",
	SilenceUsage:  true,
	SilenceErrors: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		if stdinPath != "" {
			stdinMode(stdinPath)
			return nil
		}
		return formatRepo(args)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		fmt.Fprintln(os.Stderr, "bachfmt:", err)
		os.Exit(1)
	}
}

func init() {
	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	// rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.bachfmt.yaml)")

	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	rootCmd.Flags().StringVar(&stdinPath, "stdin", "", "read a buffer from stdin, write it formatted to stdout; the value is the buffer's file path")
}
