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

- Install AWS CLI
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

###

