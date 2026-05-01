# Requirements
Items that need to be followed before deploying infrastructure to AWS using Git Actions Ci/Cd.

## Prepare GitHub Actions

### Create OIDC provider in AWS for GitHub Actions deployment

- Create IdP
    - Go to IAM -> Identity Providers -> add provider
    - Provider type = OpenID Connect
    - Provider URL = https://token.actions.githubusercontent.com
    - Audience = sts.amazonaws.com
    - Tags = "rg=FreelaMkp-CiCd"
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
    - Tags = "rg=FreelaMkp-CiCd"
    - Create Policy

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
      "Resource": "arn:aws:iam::<AWS_ACCOUNT_D>:role/*"
    }
  ]
}
```

- Configure S3 bucket and DynamoDB table
    - These are needed to save the terraform state file and do the state file locking respectively.
    - S3 bucket name:
    - DynamoDB table name: 

- Configure Terraform Backend (S3 + Locking)
    - instructions on ChatGPT

###