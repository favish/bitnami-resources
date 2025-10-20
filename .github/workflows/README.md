# GitHub Actions Workflows

This repository contains automated workflows to build Docker images for Bitnami containers.

## Workflows

### 1. `build-images.yml` - Basic Build Workflow

**Triggers:**
- Push to `main` or `dev` branches
- Pull requests to `main` branch
- Manual trigger via workflow dispatch

**Features:**
- Detects changes in specific container folders
- Builds only affected images
- Supports multi-architecture builds (amd64, arm64)
- Includes security scanning with Trivy
- Publishes to Docker Hub (docker.io)

**Path Detection:**
- `containers/redis/**` → Builds Redis images
- `containers/discourse/**` → Builds Discourse images

### 2. `advanced-build.yml` - Dynamic Matrix Build

**Triggers:**
- Push to `main` or `dev` branches
- Pull requests to `main` branch
- Weekly scheduled builds (Sundays at 2 AM UTC)
- Manual trigger with options

**Features:**
- Automatically discovers all Dockerfiles in the repository
- Generates dynamic build matrix
- Builds only changed containers (unless forced)
- Manual workflow dispatch with options:
  - Force build all images
  - Custom build platforms
- Enhanced metadata and labeling
- Build summaries

## Usage

### Automatic Builds

Images are automatically built when:
1. You push changes to container folders
2. You create a pull request
3. Weekly scheduled maintenance builds run

### Manual Builds

You can manually trigger builds:

1. Go to **Actions** tab in GitHub
2. Select **Advanced Build Matrix** workflow
3. Click **Run workflow**
4. Options:
   - **Force build all images**: Build all containers regardless of changes
   - **Build platforms**: Specify platforms (default: `linux/amd64,linux/arm64`)

### Image Tags

Built images are tagged with:
- `latest` (for main branch)
- `{version}-{variant}` (e.g., `8.2-debian-12`)
- `{version}-{variant}-{git-sha}`
- `{branch}-{git-sha}` (for branches)
- `pr-{number}` (for pull requests)
- `weekly-{date}` (for scheduled builds)

### Registry

Images are published to: `docker.io/{owner}/{container-name}`

Examples:
- `docker.io/favish/bitnami-redis:8.2-debian-12`
- `docker.io/favish/bitnami-discourse:3-debian-12`

## Security

- All images are scanned with Trivy for vulnerabilities
- Scan results are uploaded to GitHub Security tab
- Multi-architecture builds ensure broad compatibility
- Images include proper OCI labels and metadata

## Adding New Containers

To add a new container:

1. Create folder structure: `containers/{name}/{version}/{variant}/`
2. Add your Dockerfile in the variant folder
3. The workflows will automatically detect and build it

## Configuration

### Environment Variables

Set these in your GitHub repository settings:

- Repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are used for Docker Hub authentication
- No additional configuration needed for basic usage

### Customization

Modify the workflows to:
- Change build triggers
- Add different registries
- Modify security scanning
- Adjust build platforms
- Add notification integrations

## Troubleshooting

### Build Failures

1. Check the Actions tab for detailed logs
2. Review Dockerfile syntax
3. Ensure all required build contexts exist
4. Check if base images are accessible

### Security Scan Failures

- Security scans may find vulnerabilities but won't fail the build
- Review security tab for detailed vulnerability reports
- Update base images or dependencies as needed

### Matrix Generation Issues

- The advanced workflow generates matrix dynamically
- Check the "Generate build matrix" step logs
- Ensure Dockerfile paths follow the expected structure