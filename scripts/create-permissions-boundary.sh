#!/usr/bin/env bash
# ABOUTME: Creates the shared IAM permissions boundary policy for all workshop students.
# ABOUTME: Run once before creating student users. Allowlists EKS and supporting services only.

set -euo pipefail

POLICY_NAME="kcd-tx-attendee-boundary"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

echo "============================================"
echo "Creating permissions boundary: $POLICY_NAME"
echo "Account: $ACCOUNT_ID"
echo "============================================"

# Check if policy already exists
EXISTING=$(aws iam list-policies --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text 2>/dev/null)
if [ -n "$EXISTING" ]; then
    echo "Policy already exists: $EXISTING"
    echo "Delete it first if you need to update: aws iam delete-policy --policy-arn $EXISTING"
    exit 0
fi

POLICY_DOC=$(cat <<'POLICYJSON'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEKSFullAccess",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:ListNodegroups",
                "eks:DescribeNodegroup",
                "eks:AccessKubernetesApi",
                "eks:ListFargateProfiles",
                "eks:DescribeUpdate",
                "eks:ListUpdates",
                "eks:ListAddons",
                "eks:DescribeAddon"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowEC2Describe",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowEC2ForLoadBalancersAndSecurityGroups",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowElasticLoadBalancing",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowECRImagePull",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowECRPublic",
            "Effect": "Allow",
            "Action": [
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
                "ecr-public:GetRepositoryCatalogData",
                "ecr-public:GetRegistryCatalogData"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowSTS",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity",
                "sts:AssumeRole",
                "sts:GetServiceBearerToken"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowAutoScalingDescribe",
            "Effect": "Allow",
            "Action": [
                "autoscaling:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowCloudWatchReadOnly",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricData",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "logs:DescribeLogGroups",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowIAMReadAndPassRole",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:ListRoles",
                "iam:PassRole",
                "iam:GetOpenIDConnectProvider"
            ],
            "Resource": "*"
        }
    ]
}
POLICYJSON
)

ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --description "Permissions boundary for KCD Texas 2026 workshop students. Allowlists EKS and supporting services only." \
    --policy-document "$POLICY_DOC" \
    --query 'Policy.Arn' \
    --output text)

echo ""
echo "Created: $ARN"
echo ""
echo "This boundary will be attached to every student IAM user."
echo "Next: run create-attendee-users.sh"
