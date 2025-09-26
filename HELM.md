# Favish Bitnami Helm Charts 🚢

This repository contains production-ready Helm charts for Bitnami applications, customized and maintained by Favish.

## Quick Start

### Add Repository

```bash
helm repo add favish-bitnami https://favish.github.io/bitnami-resources
helm repo update
```

### Available Charts

| Chart | Description | Version |
|-------|-------------|---------|
| **discourse** | Modern discussion platform | Latest |
| **redis** | In-memory data structure store | Latest |

## Installation Examples

### Discourse

```bash
# Basic installation
helm install my-discourse favish-bitnami/discourse

# With custom values
helm install my-discourse favish-bitnami/discourse \
  --set global.storageClass=gp2 \
  --set discourse.host=forum.example.com
```

### Redis

```bash
# Basic installation  
helm install my-redis favish-bitnami/redis

# With authentication
helm install my-redis favish-bitnami/redis \
  --set auth.enabled=true \
  --set auth.password=mypassword
```

## Configuration

Each chart includes comprehensive configuration options. View available parameters:

```bash
# Show chart values
helm show values favish-bitnami/discourse
helm show values favish-bitnami/redis

# Show chart information
helm show chart favish-bitnami/discourse
helm show readme favish-bitnami/discourse
```

## Development

### Local Testing

```bash
# Clone repository
git clone https://github.com/favish/bitnami-resources.git
cd bitnami-resources

# Lint charts
helm lint charts/discourse
helm lint charts/redis

# Install locally
helm install test-discourse ./charts/discourse
helm install test-redis ./charts/redis
```

### Chart Structure

```
charts/
├── discourse/
│   ├── Chart.yaml          # Chart metadata
│   ├── values.yaml         # Default configuration
│   ├── templates/          # Kubernetes manifests
│   └── README.md           # Chart documentation
└── redis/
    ├── Chart.yaml
    ├── values.yaml  
    ├── templates/
    └── README.md
```

## Links

- 📁 **Source Code**: [GitHub Repository](https://github.com/favish/bitnami-resources)
- 🏷️ **Releases**: [Chart Releases](https://github.com/favish/bitnami-resources/releases)  
- 📄 **Repository Index**: [index.yaml](https://favish.github.io/bitnami-resources/index.yaml)
- 🐳 **Docker Images**: [GitHub Container Registry](https://github.com/orgs/favish/packages)

## Support

For questions, issues, or contributions:

1. **Issues**: [GitHub Issues](https://github.com/favish/bitnami-resources/issues)
2. **Discussions**: [GitHub Discussions](https://github.com/favish/bitnami-resources/discussions)
3. **Security**: Report via private vulnerability disclosure

---

*Maintained with ❤️ by [Favish](https://github.com/favish)*