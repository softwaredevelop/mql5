//revive:disable:package-comments,exported
package main

import (
	"context"

	"github.com/pulumi/pulumi/sdk/v3/go/auto"
	"github.com/pulumi/pulumi/sdk/v3/go/auto/debug"
	"github.com/pulumi/pulumi/sdk/v3/go/auto/optpreview"
	"github.com/pulumi/pulumi/sdk/v3/go/auto/optup"
)

// Stack defines the interface for Pulumi stack operations.
// This abstraction allows for mocking in unit tests.
type Stack interface {
	SetAllConfig(ctx context.Context, config auto.ConfigMap) error
	Refresh(ctx context.Context) (string, error)
	Preview(ctx context.Context) (string, error)
	Up(ctx context.Context) (auto.UpResult, error)
	Destroy(ctx context.Context) error
	SetEnvVars(envVars map[string]string) error
}

// pulumiStack is a real implementation of the Stack interface, wrapping the Pulumi Automation API.
type pulumiStack struct {
	stack *auto.Stack
}

// NewPulumiStack creates or selects a Pulumi stack and returns it wrapped in the Stack interface.
func NewPulumiStack(ctx context.Context, stackName, workDir string) (Stack, error) {
	s, err := auto.UpsertStackLocalSource(ctx, stackName, workDir)
	if err != nil {
		return nil, err
	}
	return &pulumiStack{stack: &s}, nil
}

// SetAllConfig sets all configuration values for the stack.
func (ps *pulumiStack) SetAllConfig(ctx context.Context, config auto.ConfigMap) error {
	return ps.stack.SetAllConfig(ctx, config)
}

// Refresh refreshes the stack's state.
func (ps *pulumiStack) Refresh(ctx context.Context) (string, error) {
	res, err := ps.stack.Refresh(ctx)
	if err != nil {
		return "", err
	}
	return res.StdOut, nil
}

// Preview previews the changes for a stack update.
func (ps *pulumiStack) Preview(ctx context.Context) (string, error) {
	res, err := ps.stack.Preview(ctx, optpreview.DebugLogging(debug.LoggingOptions{Debug: true}))
	if err != nil {
		return "", err
	}
	return res.StdOut, nil
}

// Up performs a stack update.
func (ps *pulumiStack) Up(ctx context.Context) (auto.UpResult, error) {
	return ps.stack.Up(ctx, optup.DebugLogging(debug.LoggingOptions{Debug: true}))
}

// Destroy destroys all resources in the stack.
func (ps *pulumiStack) Destroy(ctx context.Context) error {
	_, err := ps.stack.Destroy(ctx)
	return err
}

// SetEnvVars sets environment variables for the workspace.
func (ps *pulumiStack) SetEnvVars(envVars map[string]string) error {
	return ps.stack.Workspace().SetEnvVars(envVars)
}
