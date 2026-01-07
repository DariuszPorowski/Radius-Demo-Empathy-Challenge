# Radius Demo Empathy Challenge

Our last customer empathy session was over six months ago and was a great success. Rather than a group activity, this empathy session is an individual activity.

Your challenge is to build a demo using Radius to deploy the Todo List application and a PostgreSQL database to Kubernetes, AWS, and Azure. Specifically, it should:

- Use a real-world enterprise resource group and environment setup (see below)
- Use a Radius Resource Type
- Use Terraform for the Recipes
- The database passwords must be stored securely and never in cleartext
- The database password should be cryptographically strong (hint: Microsoft discourages generating passwords using Bicep)
- For extra credit, you can also deploy to ACI.

## Deliverable

You only need to build the demo, not record or present it. It should be similar to this video:

[Radius KubeCon Demo.mp4](https://microsoft.sharepoint.com/:v:/t/azure-octo-team/IQCCgpit8J90TJStV7SmiHUfARGWRuj61cXXSqVlpGM5JSY?e=I8WGCH)

Our actual deliverable is:

1. Document your learnings. What was easy? What was difficult?
2. Open issues you encounter along the way in GitHub.

## Appendix: Resource Groups and Environments

| Business Unit      | Resource Group | Environment     | Kubernetes Namespace | Cloud Environment     |
|--------------------|----------------|-----------------|----------------------|-----------------------|
| Commercial Banking | commercial     | commercial-dev  | commercial-dev       | Azure:commercial-dev  |
| Commercial Banking | commercial     | commercial-test | commercial-test      | Azure:commercial-test |
| Commercial Banking | commercial     | commercial-prod | commercial-prod      | Azure:commercial-prod |
| Operations         | operations     | operations-dev  | N/A, uses ACI        | ACI:operations-dev    |
| Operations         | operations     | operations-test | N/A, uses ACI        | ACI:operations-test   |
| Operations         | operations     | operations-prod | N/A, uses ACI        | ACI:operations-prod   |
| Retail Banking     | retail         | retail-dev      | retail-dev           | None                  |
| Retail Banking     | retail         | retail-test     | retail-test          | None                  |
| Retail Banking     | retail         | retail-prod     | retail-prod          | None                  |
| Risk               | risk           | risk-dev        | risk-dev             | AWS                   |
| Risk               | risk           | risk-test       | risk-test            | AWS                   |
| Risk               | risk           | risk-prod       | risk-prod            | AWS                   |

## Notes

Feel free to use a single Kubernetes cluster or multiple ones.
