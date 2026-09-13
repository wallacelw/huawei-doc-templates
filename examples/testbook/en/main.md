> **Info:** This document demonstrates the `testbook` template
> (`testbook.cls`) for Huawei Cloud POC/acceptance test case documents.
> It exercises all available commands and environments: cover page,
> table of contents, test case environment with all field commands, mini
> header bars, testprocedure environment with step-by-step actions,
> objectives block, code blocks, images, callouts (`warning`, `tip`,
> `infobox`), tables, badge, menu paths, weblinks, notes, param
> references, test summary table, result badges, and changelog.

# Test Cases Description

> **General Objective:** Validate the Huawei Cloud Data Platform
> deployment for the POC environment, ensuring that all core services
> (DataArts Studio, MRS, OBS, VPC) are provisioned correctly,
> accessible, and functioning as specified in the solution architecture.
>
> **Prerequisites:**
>
> -   Huawei Cloud account with IAM admin privileges in the
>     `sa-brazil-1` region.
>
> -   VPC, subnet, and security groups already created by the
>     infrastructure team.
>
> -   DataArts Studio instance (Dayu) provisioned and licensed.
>
> -   MRS cluster deployed with the required component stack (HDFS,
>     YARN, Spark, Hive).
>
> -   OBS bucket created and accessible with the designated IAM policy.
>
> -   Test execution environment with network connectivity to the Huawei
>     Cloud Console.
>
> -   `latexmk` and `terraform` CLI tools installed locally.

## Test Scope

| Domain | What Should Be Observed |
| --- | --- |
| Platform Architecture | Core services are deployed, healthy, and reachable via the Console API. |
| Data Engineering | DataArts Studio pipelines can ingest, transform, and load data into the target storage. |
| Data Storage | OBS buckets and MRS HDFS accept writes/reads with correct permissions. |
| Security | IAM policies, VPC isolation, and security group rules enforce the intended access control. |

## Preconditions and Preparations

-   All infrastructure resources must be provisioned via Terraform and
    the `terraform apply` output must show zero errors.

-   The MRS cluster must be in **Running** state before any data
    engineering test case is executed.

-   Test data files (CSV/JSON) must be uploaded to the designated OBS
    bucket prior to pipeline execution.

-   Each tester must have a personal IAM account with the **Dayu_User**
    role assigned in DataArts Studio.

-   Network firewall rules must allow inbound TCP 22 (SSH) and TCP 443
    (HTTPS) from the test execution subnet.

*Note: Ensure the test execution environment has the correct timezone
set to `America/Sao_Paulo` (GMT-3) so that log timestamps align with the
Huawei Cloud Console.*

``` bash
# Verify CLI tools are installed
terraform version
obsutil version
kubectl version --client
```

> **Tip:** Use `terraform plan` before `terraform apply` to preview
> infrastructure changes and avoid unintended resource modifications.

## Acceptance Method

| Result | Explanation |
| --- | --- |
| Satisfied | The test case passes fully --- observed behavior matches the expected result with no deviations. |
| Satisfied but with reservations | The test case passes but minor deviations were observed that do not impact the POC objectives (documented in Remarks). |
| Not satisfied | The test case fails --- observed behavior does not match the expected result. A defect report must be filed. |
| Untested | The test case could not be executed due to blocking dependencies or environment issues. |

## Test Case Summary

  ID       Title                                          Status
  -------- ---------------------------------------------- --------
  TC-001   Verify MRS cluster deployment and health       Pass
  TC-002   Verify OBS bucket creation and accessibility   Pass
  TC-003   Verify VPC and security group configuration    Pass
  TC-004   Verify DataArts Studio workspace creation      Pass
  TC-005   Verify data ingestion pipeline execution       Pass
  TC-006   Verify Spark SQL query on MRS cluster          Pass
  TC-007   Verify IAM policy enforcement on OBS buckets   Pass
  TC-008   Verify DataArts Studio data masking rule       Pass
  TC-009   Verify Terraform infrastructure deployment     Pass
  TC-010   Verify test data upload to OBS                 Pass

# Platform Architecture

## TC-001: Verify MRS cluster deployment and health

Objective
:   Confirm that the MapReduce Service (MRS) cluster is deployed with
    the required components (HDFS, YARN, Spark, Hive) and all nodes
    report a healthy status.

Prerequisites
:   testlist Terraform infrastructure apply completed successfully. MRS
    cluster ID is available in the Terraform output. IAM user has
    MRS_Viewer or higher role. testlist

Procedure

:   1.  Log in to the Huawei Cloud Console
    2.  Navigate to Console, MapReduce Service, Clusters
    3.  Locate cluster mrs-poc-cluster
    4.  Verify cluster status
    5.  Review Component tab
    6.  Review Node tab

Expected Result
:   testlist Cluster status is Running. All four components (HDFS, YARN,
    Spark, Hive) are listed with status Normal. All nodes report status
    Running with no alarms. testlist

Test Result
:   Pass

Remarks
:   If any component shows Abnormal, check the MRS alarm page before
    marking the result.

## TC-002: Verify OBS bucket creation and accessibility

Objective
:   Confirm that the Object Storage Service (OBS) bucket used for the
    POC data lake is created, has the correct storage class, and is
    accessible with the designated IAM policy.

Prerequisites
:   testlist OBS bucket name is defined in the Terraform configuration.
    IAM policy granting read/write access to the bucket is attached to
    the test user. testlist

Procedure

:   1.  Log in to the Console
    2.  Navigate to Console, Object Storage Service
    3.  Locate the bucket (e.g. poc-datalake-raw)
    4.  Verify the storage class is Standard
    5.  Upload a test file (test-upload.txt) to the bucket
    6.  Download the file and compare its content with the original
    7.  Delete the test file

Expected Result
:   testlist Bucket exists with storage class Standard. File upload
    completes without error. Downloaded file content matches the
    original. File deletion succeeds. testlist

Test Result
:   Pass

Remarks
:   OBS eventual consistency may cause a brief delay before a newly
    uploaded object appears in listings.

## TC-003: Verify VPC and security group configuration

Objective
:   Confirm that the VPC, subnet, and security groups are configured
    according to the network architecture diagram, with the correct CIDR
    blocks and inbound/outbound rules.

Prerequisites
:   testlist VPC and subnet IDs are available from the Terraform output.
    Security group names are documented in the solution architecture.
    testlist

Procedure

:   1.  Log in to the Console
    2.  Navigate to Console, Virtual Private Cloud, VPCs
    3.  Locate the VPC (e.g. vpc-poc) and verify its CIDR block matches
        the architecture (e.g. 10.0.0.0/16)
    4.  Click the subnet and verify its CIDR (e.g. 10.0.1.0/24)
    5.  Navigate to Security Groups and verify inbound rules: TCP 22
        from the bastion subnet, TCP 443 from the corporate proxy
    6.  Verify outbound rules allow all traffic (default)

Expected Result
:   testlist VPC CIDR is 10.0.0.0/16. Subnet CIDR is 10.0.1.0/24.
    Inbound rules match the architecture: TCP 22 and TCP 443 from the
    specified sources. Outbound allows all traffic. testlist

Test Result
:   Pass

Remarks
:   If the security group has additional rules beyond the architecture
    spec, document them in the Remarks field.

# Data Engineering

## TC-004: Verify DataArts Studio workspace creation

Objective
:   Confirm that the DataArts Studio (Dayu) instance is provisioned, the
    workspace is accessible, and the designated IAM users can log in
    with the Dayu_User role.

Prerequisites
:   testlist DataArts Studio instance is provisioned and its status is
    Running. Test IAM user has the Dayu_User role assigned. testlist

Procedure

:   1.  Log in to the Console with the test IAM user
    2.  Navigate to Console, DataArts Studio, Workspaces
    3.  Locate the workspace (e.g. poc-workspace)
    4.  Click Access Workspace to open the DataArts Studio console
    5.  Verify the left navigation panel loads with the expected
        modules: Data Integration, Data Development, Data Architecture

Expected Result
:   testlist Workspace is listed and accessible. DataArts Studio console
    opens without errors. All three modules (Data Integration, Data
    Development, Data Architecture) are visible in the navigation.
    testlist

Test Result
:   Pass

Remarks
:   If the workspace fails to load, check the Dayu instance status and
    the IAM role assignment.

## TC-005: Verify data ingestion pipeline execution

Objective
:   Confirm that a DataArts Studio batch pipeline can successfully
    ingest CSV data from OBS, apply a basic transformation, and write
    the result to the target OBS path.

Prerequisites
:   testlist TC-004 completed (DataArts Studio workspace accessible).
    Source CSV file (customers.csv) exists in the OBS raw bucket. Target
    OBS path (poc-datalake-curated/customers/) is configured. Pipeline
    pl-ingest-customers is published in DataArts Studio. testlist

Procedure

:   1.  Navigate to Data Development in DataArts Studio
    2.  Locate pipeline pl-ingest-customers
    3.  Click Run to execute the pipeline
    4.  Wait for pipeline status (timeout: 10 min)
    5.  Verify output file in OBS
    6.  Download and verify row count

Expected Result
:   testlist Pipeline execution completes with status Success. Output
    file is created in the target OBS path. Row count of the output file
    matches the source file. testlist

Test Result
:   Pass

Remarks
:   Pipeline execution time varies with data volume. For the POC, the
    source file contains approximately 10,000 rows.

## TC-006: Verify Spark SQL query on MRS cluster

Objective
:   Confirm that a Spark SQL query can be executed on the MRS cluster to
    read data from a Hive table and return correct results, validating
    the integration between MRS and the data lake.

Prerequisites
:   testlist TC-001 completed (MRS cluster healthy). Hive table
    poc_db.customers exists and contains data loaded by the ingestion
    pipeline. SSH access to the MRS master node is configured. testlist

Procedure

:   1.  SSH into the MRS master node
    2.  Run the Spark SQL CLI: spark-sql --master yarn -{}-conf
        spark.sql.hive.convertMetastoreOrc=true -e "SELECT COUNT(\*)
        FROM poc_db.customers;"
    3.  Verify the returned count matches the expected row count
        (10,000)
    4.  Run a sample query to verify data integrity: spark-sql --master
        yarn -e "SELECT customer_id, name FROM poc_db.customers LIMIT
        5;"
    5.  Confirm the query returns 5 rows with non-null values

Expected Result
:   testlist COUNT(\*) returns 10,000. The sample query returns 5 rows
    with valid customer_id and name values. testlist

Test Result
:   Pass

Remarks
:   If the Spark SQL CLI is not available, use the MRS Spark2x
    component's web UI to submit the query instead.

# Security and Access Control

## TC-007: Verify IAM policy enforcement on OBS buckets

Objective
:   Confirm that IAM policies correctly restrict OBS bucket access ---
    authorized users can read/write while unauthorized users are denied,
    and the bucket policy matches the principle of least privilege.

Prerequisites
:   testlist OBS bucket poc-datalake-raw exists with the designated IAM
    policy. Two test IAM users: one with OBS_ReadWrite role, one with no
    OBS permissions. obsutil CLI configured for both users. testlist

Procedure

:   1.  Using the authorized user, upload a test file to
        poc-datalake-raw
    2.  Using the authorized user, download and verify the file content
    3.  Using the unauthorized user, attempt to upload a file --- verify
        the request is denied (HTTP 403)
    4.  Using the unauthorized user, attempt to list objects in the
        bucket --- verify the request is denied
    5.  Review the bucket policy in the Console at Console, Object
        Storage Service, Bucket Policies and confirm it grants only the
        intended permissions

Expected Result
:   testlist Authorized user can upload and download successfully.
    Unauthorized user receives HTTP 403 on both upload and list
    operations. Bucket policy grants only the intended read/write
    permissions to the designated roles. testlist

Test Result
:   Pass

Remarks
:   Check the Cloud Trail logs if access denial is not returned as
    expected --- there may be a policy inheritance from the project or
    domain level.

## TC-008: Verify DataArts Studio data masking rule

Objective
:   Confirm that sensitive data columns (e.g. PII fields) are masked
    according to the DataArts Studio data masking rule when queried by
    non-admin users.

Prerequisites
:   testlist TC-004 completed (DataArts Studio workspace accessible).
    Data masking rule configured for column customers.ssn (Social
    Security Number). Test user has Dayu_User role (not admin). testlist

Procedure

:   1.  In the DataArts Studio console, navigate to Data Architecture
        \$\$ Data Masking
    2.  Verify the masking rule for customers.ssn is active and uses the
        Mask All strategy
    3.  Query the customers table as the test user via DataArts Studio
        SQL console
    4.  Verify the ssn column returns masked values
        (e.g. \*\*\*\*\*\*\*\*\*) instead of real data
    5.  Query the same table as an admin user and verify real values are
        returned

Expected Result
:   testlist Masking rule is active for customers.ssn. Non-admin user
    sees masked values in the ssn column. Admin user sees real values in
    the ssn column. testlist

Test Result
:   Pass

Remarks
:   Data masking rules apply at query time --- the underlying data in
    OBS/HDFS is not modified.

# Environment Setup and Tooling

## TC-009: Verify Terraform infrastructure deployment

Objective
:   Confirm that the Terraform configuration deploys all required
    infrastructure resources (VPC, MRS, OBS, DataArts Studio) without
    errors and the state file reflects the expected resources.

Prerequisites
:   testlist terraform CLI installed (version \$\$ 1.0). AK/SK
    credentials configured via environment variables or provider.tf.
    Terraform configuration files in the project directory. testlist

Procedure

:   1.  Navigate to the Terraform project directory
    2.  Run terraform init to initialize the working directory
    3.  Run terraform plan and review the planned changes --- confirm
        all expected resources are listed
    4.  Run terraform apply -auto-approve and wait for completion
    5.  Run terraform output and verify all output values are populated
    6.  Run terraform state list and confirm the resource count matches
        the architecture

Expected Result
:   testlist terraform apply completes with no errors. All output values
    are populated (cluster ID, bucket name, VPC ID). Resource count in
    state matches the architecture specification. testlist

Test Result
:   Pass

Remarks
:   If terraform apply fails, check the AK/SK credentials and the
    sa-brazil-1 region quota limits.

## TC-010: Verify test data upload to OBS

Objective
:   Confirm that all required test data files (CSV, JSON) can be
    uploaded to the designated OBS bucket and are accessible by the
    DataArts Studio pipeline.

Prerequisites
:   testlist TC-002 completed (OBS bucket accessible). Test data files
    prepared in the local directory ./test-data/. obsutil CLI configured
    with the test user credentials. testlist

Procedure

:   1.  List the local test data files and verify their integrity (row
        count, schema)
    2.  Upload all files to the OBS raw bucket using obsutil
    3.  Verify each file exists in OBS by listing the bucket contents
    4.  Download a sample file from OBS and compare it with the local
        original (checksum)
    5.  In DataArts Studio, verify the data source connection can read
        the uploaded files

Expected Result
:   testlist All test data files are uploaded without errors. Bucket
    listing shows all uploaded files with correct sizes. Downloaded file
    checksum matches the local original. DataArts Studio data source
    connection can read the files. testlist

Test Result
:   Pass

Remarks
:   Large files (\$\>\$1 GB) should be uploaded using the OBS multipart
    upload feature for better reliability.

*\[Image placeholder: Screenshot of the test execution dashboard showing all test case results\]*

# Changelog

**2.1.0**  *2026-09-13*

Changed teststeps from tabular table to auto-numbered paragraphs.
`\teststep` now takes 1 arg (action only). Images, code blocks, and
callouts can be placed freely between steps.

**2.0.0**  *2026-09-13*

Redesigned testcase layout: full-width mini header bars for each field,
testprocedure environment with 2-column step table, field order updated
(Test Result before Remarks).

**1.1.0**  *2026-09-13*

Added comprehensive feature demonstrations: `warning`, `tip`, `infobox`
callouts; `code` blocks; `badge`; `weblink`; `note`; `param`; `image`,
`imagecap`, and `imageplaceholder`; `menu` paths; and `inlinecode`
references.

Added Security and Access Control test cases (TC-007, TC-008).

Added Environment Setup and Tooling test cases (TC-009, TC-010).

**1.0.0**  *2026-09-13*

Initial version.

Added Platform Architecture test cases (TC-001 to TC-003).

Added Data Engineering test cases (TC-004 to TC-006).
