#!/usr/bin/env bash
# ABOUTME: Creates temporary IAM users for workshop students in a single shared account.
# ABOUTME: Attaches permissions boundary, scoped IAM policy, patches aws-auth, writes connection cards.

set -euo pipefail

STUDENT_COUNT="${1:?Usage: $0 <student_count> <region>}"
REGION="${2:?Usage: $0 <student_count> <region>}"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/kcd-texas-student-boundary"
CLUSTER_PREFIX="kcd-texas-student"
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

    # Patch aws-auth ConfigMap on the student's cluster
    echo "  Patching aws-auth on cluster $CLUSTER..."
    aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --kubeconfig "/tmp/kubeconfig-${CLUSTER}" 2>/dev/null

    KUBECTL="kubectl --kubeconfig /tmp/kubeconfig-${CLUSTER}"
    USERARN="arn:aws:iam::${ACCOUNT_ID}:user/${USER}"

    # Get current mapUsers, append this student
    CURRENT_MAP=$($KUBECTL get configmap aws-auth -n kube-system -o jsonpath='{.data.mapUsers}' 2>/dev/null || echo "[]")

    # Build new entry
    NEW_ENTRY="- userarn: ${USERARN}
  username: ${USER}
  groups:
    - system:masters"

    if echo "$CURRENT_MAP" | grep -q "$USERARN" 2>/dev/null; then
        echo "  User already in aws-auth, skipping patch."
    else
        if [ "$CURRENT_MAP" = "[]" ] || [ -z "$CURRENT_MAP" ]; then
            UPDATED_MAP="$NEW_ENTRY"
        else
            UPDATED_MAP="${CURRENT_MAP}
${NEW_ENTRY}"
        fi

        $KUBECTL patch configmap aws-auth -n kube-system \
            --type strategic \
            -p "{\"data\":{\"mapUsers\":\"${UPDATED_MAP}\"}}" 2>/dev/null && \
            echo "  Patched aws-auth with system:masters." || \
            echo "  WARNING: Could not patch aws-auth. Manual update may be needed."
    fi

    rm -f "/tmp/kubeconfig-${CLUSTER}"

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
