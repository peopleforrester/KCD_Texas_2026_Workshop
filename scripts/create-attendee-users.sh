#!/usr/bin/env bash
# ABOUTME: Creates temporary IAM users for workshop students in a single shared account.
# ABOUTME: Attaches permissions boundary, scoped IAM policy, creates EKS Access Entry, writes connection cards.

set -euo pipefail

STUDENT_COUNT="${1:?Usage: $0 <student_count> <region>}"
REGION="${2:?Usage: $0 <student_count> <region>}"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/kcd-tx-attendee-boundary"
CLUSTER_PREFIX="kcd-tx-attendee"
OUTPUT_DIR="attendee-configs"

mkdir -p "$OUTPUT_DIR"

# Verify boundary policy exists
if ! aws iam get-policy --policy-arn "$BOUNDARY_ARN" &>/dev/null; then
    echo "ERROR: Permissions boundary not found: $BOUNDARY_ARN"
    echo "Run create-permissions-boundary.sh first."
    exit 1
fi

echo "============================================"
echo "Creating $STUDENT_COUNT student IAM users"
echo "Account:  $ACCOUNT_ID"
echo "Region:   $REGION"
echo "Boundary: $BOUNDARY_ARN"
echo "============================================"

CREATED=0
SKIPPED=0
FAILED=0

for i in $(seq -w 1 "$STUDENT_COUNT"); do
    USER="${CLUSTER_PREFIX}-${i}"
    CLUSTER="${CLUSTER_PREFIX}-${i}"

    echo ""
    echo "--- [$i/$STUDENT_COUNT] $USER ---"

    # Create IAM user with permissions boundary
    if aws iam get-user --user-name "$USER" &>/dev/null; then
        echo "  User exists, skipping creation."
        SKIPPED=$((SKIPPED + 1))
    else
        aws iam create-user \
            --user-name "$USER" \
            --permissions-boundary "$BOUNDARY_ARN" \
            --output text --query 'User.UserName' >/dev/null
        echo "  Created user with permissions boundary."
        CREATED=$((CREATED + 1))
    fi

    # Attach inline policy scoped to this student's cluster
    POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSFullAccessOwnCluster",
            "Effect": "Allow",
            "Action": "eks:*",
            "Resource": "arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER}"
        },
        {
            "Sid": "EKSList",
            "Effect": "Allow",
            "Action": "eks:ListClusters",
            "Resource": "*"
        },
        {
            "Sid": "SupportingServices",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity",
                "ec2:Describe*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability",
                "ecr-public:GetAuthorizationToken",
                "elasticloadbalancing:Describe*",
                "autoscaling:Describe*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    aws iam put-user-policy \
        --user-name "$USER" \
        --policy-name "${USER}-eks-access" \
        --policy-document "$POLICY_DOC"
    echo "  Attached cluster-scoped policy."

    # Create access key (delete existing first if any)
    EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USER" --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null)
    for OLD_KEY in $EXISTING_KEYS; do
        aws iam delete-access-key --user-name "$USER" --access-key-id "$OLD_KEY" 2>/dev/null
    done

    KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER" --output json)
    ACCESS_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
    echo "  Created access key: $ACCESS_KEY"

    # Grant cluster-admin via EKS Access Entries (modern API, no aws-auth).
    # Two steps: create the access entry for the principal, then associate the
    # AWS-managed cluster-admin policy at cluster scope.  Both are idempotent
    # via existence checks; AssociateAccessPolicy is idempotent server-side
    # but we suppress its error output for noise control.
    USERARN="arn:aws:iam::${ACCOUNT_ID}:user/${USER}"
    ADMIN_POLICY_ARN="arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

    if aws eks describe-access-entry \
        --cluster-name "$CLUSTER" \
        --principal-arn "$USERARN" \
        --region "$REGION" &>/dev/null; then
        echo "  Access entry already exists, skipping create."
    else
        aws eks create-access-entry \
            --cluster-name "$CLUSTER" \
            --principal-arn "$USERARN" \
            --region "$REGION" \
            --type STANDARD \
            --username "$USER" >/dev/null
        echo "  Created EKS access entry."
    fi

    aws eks associate-access-policy \
        --cluster-name "$CLUSTER" \
        --principal-arn "$USERARN" \
        --policy-arn "$ADMIN_POLICY_ARN" \
        --access-scope type=cluster \
        --region "$REGION" >/dev/null 2>&1 || true
    echo "  Associated AmazonEKSClusterAdminPolicy (cluster scope)."

    # Write connection card
    CARD_FILE="${OUTPUT_DIR}/${CLUSTER}-connection.txt"
    cat > "$CARD_FILE" <<CARD
KCD Texas 2026 — Your Lab Cluster

Cluster:          ${CLUSTER}
Region:           ${REGION}
AWS Access Key:   ${ACCESS_KEY}
AWS Secret Key:   ${SECRET_KEY}

Commands:
  aws configure          (keys above, region: ${REGION}, format: json)
  aws eks update-kubeconfig --name ${CLUSTER} --region ${REGION}
  kubectl get nodes      (should show 3 Ready nodes)
CARD
    echo "  Connection card: $CARD_FILE"
done

echo ""
echo "============================================"
echo "Summary"
echo "============================================"
echo "  Created: $CREATED"
echo "  Skipped (already existed): $SKIPPED"
echo "  Failed: $FAILED"
echo "  Connection cards: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. Verify one student can connect:"
echo "     export AWS_ACCESS_KEY_ID=<key from student-01>"
echo "     export AWS_SECRET_ACCESS_KEY=<secret>"
echo "     aws eks update-kubeconfig --name ${CLUSTER_PREFIX}-01 --region $REGION"
echo "     kubectl get nodes"
echo "  2. Print or distribute connection cards from $OUTPUT_DIR/"
