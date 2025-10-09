# VSA Generation Demo

Complete demonstration of VSA (Verification Summary Attestation) generation without modifying production code.

## Quick Start

```bash
./hack/demos/demo-vsa-generation.sh
```

## Prerequisites

- Kind cluster with Knative installed (`make setup-knative`)
- Conforma service deployed (`make deploy-local`)
- Docker/Podman running
- `cosign` CLI installed
- `tkn` CLI (optional, for viewing logs)

## What It Does

1. Sets up in-cluster Docker registry
2. Builds and pushes test image
3. Generates Cosign keys and signs image
4. Creates SLSA provenance attestation
5. Configures Konflux resources (ReleasePlan, RPA, ECP)
6. Creates Snapshot to trigger VSA generation
7. Monitors TaskRun execution
8. Shows VSA generation and Rekor upload
9. Cleans up automatically (even on Ctrl+C)

**Duration:** ~3-5 minutes

## Architecture

```
Snapshot → Service receives CloudEvent → Lookup ReleasePlan/RPA/ECP
    ↓
Create TaskRun → EC validates image → Generate VSA → Upload to Rekor
```

## Demo Files

- `demo-vsa-generation.sh` - Main executable script
- `vsa-demo-resources.yaml` - Konflux resources (ReleasePlan, RPA, ECP)
- `in-cluster-registry.yaml` - Registry deployment
- `test-app/` - Sample application

## Key Resources

**ReleasePlan**: Links `vsa-demo-application` to release process  
**ReleasePlanAdmission**: Specifies policy (`vsa-demo-policy`)  
**EnterpriseContractPolicy**: Defines validation rules and public key  
**Snapshot**: Triggers VSA generation workflow

## Troubleshooting

**No TaskRun created?**
```bash
kubectl logs -l app=conforma-knative-service -n default --tail=20
kubectl get releaseplan -n default
kubectl get releaseplanadmission -n rhtap-releng-tenant
```

**Image not accessible?**
```bash
kubectl get pods -n registry
curl http://localhost:5001/v2/
```

**Port 5001 in use?**
```bash
pkill -f "port-forward.*5001"
```

## Customization

Edit `vsa-demo-resources.yaml` to:
- Change policy configuration
- Use different validation rules
- Modify public key references

Replace `test-app/` with your own application for real-world testing.

## Cleanup

Automatic! The demo cleans up all resources on:
- Successful completion
- Script interruption (Ctrl+C)  
- Errors

## Learn More

- [Conforma](https://conforma.dev/)
- [Tekton](https://tekton.dev/)
- [Cosign](https://docs.sigstore.dev/cosign/)
- [SLSA Framework](https://slsa.dev/)
