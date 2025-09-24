# Harbor Deployment with Terraform

This repository contains the Infrastructure-as-Code (IaC) setup for deploying **Harbor** (an open-source container registry) on **AWS EC2** using **Terraform**.  

## Overview

- **Infrastructure tool:** Terraform  
- **Cloud provider:** AWS  
- **Service deployed:** Harbor (private container registry)  
- **Domain:** `harbor.flochai.com`  
- **Security:** SSL certificates + environment-managed secrets  
- **Storage:** Root (8 GB) + Data volume (40 GB) for Harbor  

Harbor provides role-based access control, image scanning, replication between registries, and a web UI to manage container images.  

---

## Architecture

1. **Terraform** provisions:
   - A custom EC2 instance on AWS.  
   - Root volume (8 GB) + separate EBS volume (40 GB) for Harbor data.  
   - Security groups to allow HTTPS traffic.  
   - Elastic IP (EIP) association to keep a fixed public IP.  

2. **User Data** bootstraps Harbor installation:
   - Downloads and installs Harbor.  
   - Applies SSL configuration.  
   - Starts Harbor services.  

3. **Secrets Management**:
   - The Harbor admin password is passed as an **environment variable**, never hardcoded.  

---

## Terraform Variables

| Variable        | Description                         | Example                  |
|-----------------|-------------------------------------|--------------------------|
| `ami`           | AMI ID for the EC2 instance         | `ami-0c101f26f147fa7fd`  |
| `instance_type` | EC2 instance type                   | `t2.medium`              |
| `region`        | AWS region                          | `eu-west-2`              |
| `key_name`      | SSH key for access                  | `harbor-key`             |
| `admin_password`| Harbor admin password (env only)    | `export HARBOR_ADMIN_PWD=xxxx` |

---

## SSL Configuration

After provisioning, update `harbor.yml` with your certificate and key paths:  

```yaml
https:
  port: 443
  certificate: /etc/ssl/certs/harbor.crt
  private_key: /etc/ssl/private/harbor.key
```
If you want to use this, don't forget to change the hostname to your own website as well as the password. 

Security Notes

- No hardcoded secrets in Terraform code.
- Certificates are provided externally and mounted into Harbor.
- Only HTTPS traffic is enabled for secure communication.

⸻

References

- Harbor Documentation
- Terraform AWS Provider
