//revive:disable:package-comments,exported
package main

import (
	"github.com/pulumi/pulumi-github/sdk/v6/go/github"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// GithubResources holds the created GitHub resources, making them accessible for testing and exporting.
type GithubResource struct {
	Repository *github.Repository
}

// defineInfrastructure defines the GitHub resources for the project.
// It is separated from main() to be independently testable.
func defineInfrastructure(ctx *pulumi.Context) (*GithubResource, error) {
	repositoryName := "mql5"
	repositoryDescription := "Mirror of my ForgeMQL5 repository for MetaTrader 5. Synced to GitHub for backup and easier collaboration."
	repository, err := github.NewRepository(ctx, "newRepositoryMql5", &github.RepositoryArgs{
		DeleteBranchOnMerge: pulumi.Bool(true),
		Description:         pulumi.String(repositoryDescription),
		HasIssues:           pulumi.Bool(true),
		HasProjects:         pulumi.Bool(true),
		Name:                pulumi.String(repositoryName),
		Topics: pulumi.StringArray{
			pulumi.String("github"),
			pulumi.String("golang"),
			pulumi.String("mql5"),
			pulumi.String("mt5"),
			pulumi.String("pulumi"),
			pulumi.String("trading"),
			pulumi.String("vscode"),
		},
		Visibility: pulumi.String("public"),
		// VulnerabilityAlerts: pulumi.Bool(true),
	}, pulumi.Protect(true))
	if err != nil {
		return nil, err
	}

	_, err = github.NewBranchProtection(ctx, "branchProtection", &github.BranchProtectionArgs{
		RepositoryId:          repository.NodeId,
		Pattern:               pulumi.String("main"),
		RequiredLinearHistory: pulumi.Bool(true),
	}, pulumi.Protect(true))
	if err != nil {
		return nil, err
	}

	return &GithubResource{
		Repository: repository,
	}, nil
}

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		resources, err := defineInfrastructure(ctx)
		if err != nil {
			return err
		}

		// Export outputs from the returned resources
		ctx.Export("repository", resources.Repository.Name)
		ctx.Export("repositoryUrl", resources.Repository.HtmlUrl)
		return nil
	})
}
