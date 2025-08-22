//revive:disable:package-comments,exported
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/pulumi/pulumi/sdk/v3/go/auto"
)

func main() {
	ctx := context.Background()

	// Configuration
	stackProjectName := "github-repos"
	stackEnvironmentName := "prod-mql5"
	workDir := "pulumi-github-main"
	pulumiOrganizationName := os.Getenv("PULUMI_ORG_NAME")
	pulumiAccessToken := os.Getenv("PULUMI_ACCESS_TOKEN")

	// Validate required environment variables
	if pulumiOrganizationName == "" || pulumiAccessToken == "" {
		log.Fatal("PULUMI_ORG_NAME and PULUMI_ACCESS_TOKEN must be set")
	}

	configMap := auto.ConfigMap{
		"github:token": auto.ConfigValue{
			Value:  os.Getenv("GITHUB_TOKEN"),
			Secret: true,
		},
		"github:owner": auto.ConfigValue{
			Value:  os.Getenv("GITHUB_OWNER"),
			Secret: true,
		},
	}

	// Create or select the stack
	pulumiStackName := auto.FullyQualifiedStackName(pulumiOrganizationName, stackProjectName, stackEnvironmentName)
	stack, err := NewPulumiStack(ctx, pulumiStackName, workDir)
	if err != nil {
		log.Fatalf("Failed to create or select stack: %v", err)
	}
	log.Println("Stack", pulumiStackName, "ready")

	// Deploy the stack
	outputs, err := deployStack(ctx, stack, pulumiAccessToken, configMap)
	if err != nil {
		log.Fatalf("Stack deployment failed: %v", err)
	}

	log.Println("Stack deployment completed successfully")
	if len(outputs) > 0 {
		log.Println("Stack outputs:")
		for k, v := range outputs {
			// Note: Secret outputs will be encrypted in the log.
			log.Printf("- %s: %s\n", k, v.Value)
		}
	}
}

// deployStack orchestrates the deployment of a Pulumi stack.
// It is designed to be testable by accepting a Stack interface.
func deployStack(ctx context.Context, stack Stack, pulumiAccessToken string, configMap auto.ConfigMap) (map[string]auto.OutputValue, error) {
	err := stack.SetEnvVars(map[string]string{
		"PULUMI_SKIP_UPDATE_CHECK": "true",
		"PULUMI_CONFIG_PASSPHRASE": "",
		"PULUMI_ACCESS_TOKEN":      pulumiAccessToken,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to set environment variables: %w", err)
	}

	err = stack.SetAllConfig(ctx, configMap)
	if err != nil {
		return nil, fmt.Errorf("failed to set config: %w", err)
	}

	log.Println("Refreshing stack...")
	refrOut, err := stack.Refresh(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to refresh stack: %w", err)
	}
	log.Println(refrOut)

	log.Println("Previewing stack...")
	prevOut, err := stack.Preview(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to preview stack: %w", err)
	}
	log.Println(prevOut)

	log.Println("Updating stack...")
	upResult, err := stack.Up(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to update stack: %w", err)
	}
	log.Println(upResult.StdOut)

	return upResult.Outputs, nil
}
