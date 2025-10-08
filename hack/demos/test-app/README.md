# VSA Generation Demo Application

This is a simple test application used to demonstrate VSA (Verified Source Attestation) generation.

## Purpose

This application is built specifically to:
- Have no existing VSAs in Rekor transparency log
- Be signed with our demo keys
- Trigger actual VSA generation (not just validation)

## Usage

This application is used by `hack/demo-vsa-generation.sh` to demonstrate the complete VSA generation workflow.

## Application Behavior

The application simply:
1. Prints demo information
2. Runs indefinitely (for container health)
3. Provides a target for VSA generation testing
