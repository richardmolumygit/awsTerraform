#!/usr/bin/env bash
set -euo pipefail

readonly app_domain="app.sugarshacktreats.com"
readonly root_zone="sugarshacktreats.com."
readonly app_zone="${app_domain}."
readonly external_dns_record="external-dns-${app_domain}."

if [[ "${1:-}" != "cleanup" ]]; then
  echo "Usage: $0 cleanup" >&2
  exit 2
fi

: "${AWS_REGION:?AWS_REGION must be set to the EKS cluster region}"
environment="${TF_ENVIRONMENT:?TF_ENVIRONMENT must be set}"
cluster_name="${environment}-eks-cluster"
owner_marker="external-dns/owner=${cluster_name}"

hosted_zones="$(aws route53 list-hosted-zones --output json)"
mapfile -t zone_ids < <(
  jq -r --arg root "$root_zone" --arg app "$app_zone" '
    .HostedZones[]?
    | select(.Config.PrivateZone == false and (.Name == $root or .Name == $app))
    | .Id
    | sub("^/hostedzone/"; "")
  ' <<< "$hosted_zones"
)

if ((${#zone_ids[@]} == 0)); then
  echo "No matching public Route 53 hosted zone found; skipping Route 53 cleanup."
  exit 0
fi

declare -A zone_records
has_acm_validation_records=false
for zone_id in "${zone_ids[@]}"; do
  zone_records[$zone_id]="$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --output json)"
  if jq -e '
    any(.ResourceRecordSets[]?;
      .Type == "CNAME"
      and (.Name | test("^_[^.]+\\.app\\.sugarshacktreats\\.com\\.$"; "i"))
      and any(.ResourceRecords[]?; .Value | test("\\.acm-validations\\.aws\\.?$"; "i")))
  ' <<< "${zone_records[$zone_id]}" >/dev/null; then
    has_acm_validation_records=true
  fi
done

active_acm_records='[]'
if [[ "$has_acm_validation_records" == true ]]; then
  mapfile -t regions < <(
    aws ec2 describe-regions --all-regions --output json \
      | jq -r '.Regions[] | select(.OptInStatus == "opt-in-not-required" or .OptInStatus == "opted-in") | .RegionName'
  )

  for region in "${regions[@]}"; do
    mapfile -t certificate_arns < <(
      aws acm list-certificates --region "$region" --output json \
        | jq -r '.CertificateSummaryList[]?.CertificateArn'
    )

    for certificate_arn in "${certificate_arns[@]}"; do
      validation_records="$(aws acm describe-certificate \
        --region "$region" \
        --certificate-arn "$certificate_arn" \
        --output json \
        | jq -c '[.Certificate.DomainValidationOptions[]?.ResourceRecord | select(.Type == "CNAME" and .Name != null and .Value != null) | {Name, Value}]')"
      active_acm_records="$(jq -cn \
        --argjson current "$active_acm_records" \
        --argjson next "$validation_records" \
        '$current + $next | unique_by([.Name, .Value])')"
    done
  done
fi

for zone_id in "${zone_ids[@]}"; do
  records_to_delete="$(jq -c \
    --arg app "${app_domain}." \
    --arg external_dns "$external_dns_record" \
    --arg owner "$owner_marker" \
    --argjson active "$active_acm_records" '
      .ResourceRecordSets as $records
      | ($records | any(.[];
          .Name == $external_dns
          and .Type == "TXT"
          and (.ResourceRecords | length > 0)
          and all(.ResourceRecords[]; .Value | contains($owner))
        )) as $owned_app_records
      | [
          $records[] as $record
          | select(
              ($owned_app_records
                and $record.Name == $app
                and ($record.Type == "A" or $record.Type == "AAAA"))
              or ($record.Name == $external_dns
                and $record.Type == "TXT"
                and any($record.ResourceRecords[]?; .Value | contains($owner)))
              or ($record.Type == "CNAME"
                and ($record.Name | test("^_[^.]+\\.app\\.sugarshacktreats\\.com\\.$"; "i"))
                and any($record.ResourceRecords[]?; .Value | test("\\.acm-validations\\.aws\\.?$"; "i"))
                and all($record.ResourceRecords[]?; . as $rr
                  | (any($active[]; .Name == $record.Name and .Value == $rr.Value) | not)))
            )
        ]
    ' <<< "${zone_records[$zone_id]}")"

  if [[ "$records_to_delete" == "[]" ]]; then
    continue
  fi

  jq -r '.[] | "Deleting \(.Type) \(.Name) from Route 53 zone."' <<< "$records_to_delete"
  change_batch="$(jq -cn --argjson records "$records_to_delete" '
    {Comment: "Remove sandbox-owned app DNS records", Changes: [$records[] | {Action: "DELETE", ResourceRecordSet: .}]}
  ')"
  aws route53 change-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --change-batch "$change_batch" >/dev/null
done