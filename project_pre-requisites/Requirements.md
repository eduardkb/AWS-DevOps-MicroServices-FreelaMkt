# Requirements
Items that need to be followed before deploying infrastructure to AWS using Git Actions Ci/Cd.

## Prepare GitHub Actions

### Create OIDC provider in AWS for GitHub Actions deployment

- Create IdP
    - Go to IAM -> Identity Providers -> add provider
    - Provider type = OpenID Connect
    - Provider URL = https://token.actions.githubusercontent.com
    - Audience = sts.amazonaws.com
    - Tags = "rg=FreelaMkp-CiCd; name=GitHub-IdP"

### Create Role and Custom Policy

- Create Role
    - Go to IAM → Roles → Create role
    - Trusted identity type = Web Identity
    - Provider = provider created above
    - Audience = sts.amazonaws.com
    - Fillout git org, repo and branch
    - On Add Permissions screen click next
    - Name = "FreelaMkp-GitCiCd-Role"
    - Use Trust Policy on file `cicd_role.json`
    - Tags = "rg=FreelaMkp-CiCd"
    - Create Role


- Create a Custom Policy and attach to the Role
    - IAM -> Policies -> Create Policy -> JSON
    - Use Policy definition on file `cicd_custom_policy.json`
    - click next and name policy as "FreelaMkp-GitCiCd-Policy"
    - Tags = "rg=FreelaMkp-CiCd; name=FreelaMkp-Policy"
    - Create Policy
    - Go back to the role and attach this policy to it.


### Create S3 Bucket for Terraform State File

- Install AWS CLIO
    - choco install awscli
- Configure Account
    - $> aws configure
        - AWS Access Key ID [None]: <SECRET>
        - AWS Secret Access Key [None]: <SECRET>
        - AWS Session Token [None]: <SECRET>
        - Default region name [None]: us-east-1
        - Default output format [None]: json
    - Show Account:
        - $> aws sts get-caller-identity
- Configure CLI Auto-Completion
    - Follow instructions: [cli-configure-completion](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-completion.html)
    - TAB = auto-complete
    - CTRL+SPACE = list available commands
- Create S3

```sh
aws s3api create-bucket `
  --bucket freelamkp-tfstate `
  --region us-east-1
```

- Secure S3 Bucket

```sh
aws s3api put-public-access-block `
  --bucket freelamkp-tfstate `
  --public-access-block-configuration `
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

- Add tags to S3 Bucket

```sh
aws s3api put-bucket-tagging `
  --bucket freelamkp-tfstate `
  --tagging "TagSet=[{Key=Name,Value=FreelaMkp-TfState},{Key=id,Value=FreelaMkp-CiCd}]"
```

### Enable CloudTrail

Enable AWS CloudTrail to have management events sent to S3 bucket. 

## Other Requirements:

### Service Linked Role for AWS ECS

- If this is a new account, make sure the ECS Service Linked Role is active

```sh
aws iam create-service-linked-role \
  --aws-service-name ecs.amazonaws.com
```

### DNS Configuration

- Create a new Route53 Hosted Zone on the project's region.
- The DNS Zone will be imported on ingress module.
- So, on file `\terraform\global\variables.tf` change the variables:
    - application_dns_zone
    - application_dns_prefix

- Export / Import Hosted Zone:
- to export, execute command below in CLI:
```sh
aws route53 list-resource-record-sets \
  --hosted-zone-id [zone-id] > route53-backup.json
```
Exported `edukb.site` zone:
```json
{
    "ResourceRecordSets": [
        {
            "Name": "edukb.site.",
            "Type": "NS",
            "TTL": 172800,
            "ResourceRecords": [
                {
                    "Value": "ns-187.awsdns-23.com."
                },
                {
                    "Value": "ns-1051.awsdns-03.org."
                },
                {
                    "Value": "ns-1659.awsdns-15.co.uk."
                },
                {
                    "Value": "ns-976.awsdns-58.net."
                }
            ]
        },
        {
            "Name": "edukb.site.",
            "Type": "SOA",
            "TTL": 900,
            "ResourceRecords": [
                {
                    "Value": "ns-187.awsdns-23.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
                }
            ]
        }
    ]
}
```

- to import, this file cannot be used directly. It must be in a special format (BIND format). to do so, it has to be exported with tools like `cli53`.
