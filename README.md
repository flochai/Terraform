## Terraform Modules Repository

This repository contains my collection of reusable Terraform modules for building cloud-native and DevOps infrastructure.
Each module is designed to be modular, configurable, and production-ready, following infrastructure-as-code best practices.

---

### Available Modules
<br>

1. Harbor Deployment (harbor/)
   
   - Provisions an EC2 instance on AWS.
   - Installs and configures Harbor (open-source container registry).
   - Bootstraps with Docker & Docker Compose.
   - Supports attaching a data disk for persistent storage.
   - Configurable admin password and TLS certificates.

👉 Use this module when you need a secure private registry for storing container images.

⸻

2. k3s Deployment (k3s/)
   
   - Provisions a lightweight Kubernetes (k3s) cluster on AWS EC2.
   - Single-node by default, but configurable for multi-node setups.
   - Installs k3s with systemd service management.
   - Installs ArgoCD, certificate manager, k9s
   - Outputs the kubeconfig file for direct kubectl access.
   - Easy to integrate with Argo CD and GitOps workflows.

👉 Use this module when you need a lightweight, cost-efficient Kubernetes cluster for experiments, testing, or small production workloads.

⸻

Prerequisites

	•	Terraform >= 1.5.0
	•	An AWS account with credentials configured (via aws configure or environment variables).
	•	SSH key pair for EC2 instances.
	•	Domain/DNS configured if you want TLS ingress (e.g., for Harbor UI).

  
⸻

Security Notes

	•	Do not commit secrets (passwords, private keys) into this repository.
	•	Use Terraform variables + environment files (.tfvars) or a secret manager (e.g., AWS SSM, Vault).
	•	Rotate SSH keys and admin passwords regularly.

---

Roadmap

	•	Add module for Argo CD bootstrap.
	•	Add module for monitoring stack (Prometheus + Grafana).
	•	Add module for Kyverno / Kubescape integration.
	•	Expand k3s module to support multi-node clusters with load balancer.

⸻

🤝 Contributing

This repo is primarily for my own projects, but feedback and suggestions are welcome. If you see improvements, feel free to open an issue or PR.

⸻

📜 License

MIT License — feel free to use and adapt these modules in your own projects.
