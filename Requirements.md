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
    - Use Trust Policy below
    - Tags = "rg=FreelaMkp-CiCd"
    - Create Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_D>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:eduardkb/AWS-DevOps-MicroServices-FreelaMkt:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

- Create a Custom Policy and attach to the Role
    - IAM -> Policies -> Create Policy -> JSON
    - Use Policy definition below
    - click next and name policy as "FreelaMkp-GitCiCd-Policy"
    - Tags = "rg=FreelaMkp-CiCd; name=FreelaMkp-Policy"
    - Create Policy
    - Go back to the role and attach this policy to it.

```Json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3State",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSAurora",
      "Effect": "Allow",
      "Action": [
        "rds:*",
        "rds-data:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Networking",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": "arn:aws:iam::<AWS_ACCOUNT_D>:role/github-actions-*",
        "Condition": {
            "StringEquals": {
            "iam:PassedToService": [
                "ec2.amazonaws.com",
                "rds.amazonaws.com"
            ]
            }
        }
    }
  ]
}
```

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

### Create DynamoDB table for TF state locking

- Create DynamoDB table: 

```sh
aws dynamodb create-table `
  --table-name FreelaMkp-terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region us-east-1 `
  --tags '[{"Key":"Name","Value":"FreelaMkp-TfLock"},{"Key":"id","Value":"FreelaMkp-CiCd"}]'
```

###

