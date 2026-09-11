> **Info:** This document demonstrates the `testbook` template
> (`testbook.cls`) for Huawei Cloud POC/acceptance test case documents.
> It exercises all available commands and environments: cover page,
> table of contents, test case environment with all field commands,
> objectives block, code blocks, images, callouts, tables, badge, and
> changelog.

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

## Acceptance Method

| Result | Explanation |
| --- | --- |
| Satisfied | The test case passes fully --- observed behavior matches the expected result with no deviations. |
| Satisfied but with reservations | The test case passes but minor deviations were observed that do not impact the POC objectives (documented in Remarks). |
| Not satisfied | The test case fails --- observed behavior does not match the expected result. A defect report must be filed. |
| Untested | The test case could not be executed due to blocking dependencies or environment issues. |

# Platform Architecture

## TC-001: Verify MRS cluster deployment and health

  Field       Description
  ----------- --------------------------------------------------------------
  Objective   Confirm that the MapReduce Service (MRS) cluster is deployed

    with the required components (HDFS, YARN, Spark, Hive) and all nodes
    report a healthy status. |

| Prerequisites \| 1. Terraform infrastructure apply completed
  successfully. 2. MRS cluster ID is available in the Terraform output.
  3. IAM user has MRS_Viewer or higher role. \|
| Procedure \| 1. Log in to the Huawei Cloud Console. 2. Navigate to
  Console, MapReduce Service, Clusters. 3. Locate the cluster by its
  name (e.g. mrs-poc-cluster). 4. Verify the cluster status is Running.
  5. Click the cluster name and review the Component tab --- confirm
  HDFS, YARN, Spark, and Hive are listed with status Normal. 6. Review
  the Node tab --- confirm all master and core nodes show status
  Running. \|
| Expected Result \| 1. Cluster status is Running. 2. All four
  components (HDFS, YARN, Spark, Hive) are listed with status Normal. 3.
  All nodes report status Running with no alarms. \|
| Remarks \| If any component shows Abnormal, check the MRS alarm page
  before marking the result. \|
| Test Result \| Pass \|

## TC-002: Verify OBS bucket creation and accessibility

  Field       Description
  ----------- -----------------------------------------------------------
  Objective   Confirm that the Object Storage Service (OBS) bucket used

    for the POC data lake is created, has the correct storage class, and
    is accessible with the designated IAM policy. |

| Prerequisites \| 1. OBS bucket name is defined in the Terraform
  configuration. 2. IAM policy granting read/write access to the bucket
  is attached to the test user. \|
| Procedure \| 1. Log in to the Console. 2. Navigate to Console, Object
  Storage Service. 3. Locate the bucket (e.g. poc-datalake-raw). 4.
  Verify the storage class is Standard. 5. Upload a test file
  (test-upload.txt) to the bucket. 6. Download the file and compare its
  content with the original. 7. Delete the test file. \|
| Expected Result \| 1. Bucket exists with storage class Standard. 2.
  File upload completes without error. 3. Downloaded file content
  matches the original. 4. File deletion succeeds. \|
| Remarks \| OBS eventual consistency may cause a brief delay before a
  newly uploaded object appears in listings. \|
| Test Result \| Pass \|

## TC-003: Verify VPC and security group configuration

  Field       Description
  ----------- -------------------------------------------------------
  Objective   Confirm that the VPC, subnet, and security groups are

    configured according to the network architecture diagram, with the
    correct CIDR blocks and inbound/outbound rules. |

| Prerequisites \| 1. VPC and subnet IDs are available from the
  Terraform output. 2. Security group names are documented in the
  solution architecture. \|
| Procedure \| 1. Log in to the Console. 2. Navigate to Console, Virtual
  Private Cloud, VPCs. 3. Locate the VPC (e.g. vpc-poc) and verify its
  CIDR block matches the architecture (e.g. 10.0.0.0/16). 4. Click the
  subnet and verify its CIDR (e.g. 10.0.1.0/24). 5. Navigate to Security
  Groups and verify inbound rules: TCP 22 from the bastion subnet, TCP
  443 from the corporate proxy. 6. Verify outbound rules allow all
  traffic (default). \|
| Expected Result \| 1. VPC CIDR is 10.0.0.0/16. 2. Subnet CIDR is
  10.0.1.0/24. 3. Inbound rules match the architecture: TCP 22 and TCP
  443 from the specified sources. 4. Outbound allows all traffic. \|
| Remarks \| If the security group has additional rules beyond the
  architecture spec, document them in the Remarks field. \|
| Test Result \| Pass \|

# Data Engineering

## TC-004: Verify DataArts Studio workspace creation

  Field       Description
  ----------- -----------------------------------------------------
  Objective   Confirm that the DataArts Studio (Dayu) instance is

    provisioned, the workspace is accessible, and the designated IAM
    users can log in with the Dayu\_User role. |

| Prerequisites \| 1. DataArts Studio instance is provisioned and its
  status is Running. 2. Test IAM user has the Dayu_User role assigned.
  \|
| Procedure \| 1. Log in to the Console with the test IAM user. 2.
  Navigate to Console, DataArts Studio, Workspaces. 3. Locate the
  workspace (e.g. poc-workspace). 4. Click Access Workspace to open the
  DataArts Studio console. 5. Verify the left navigation panel loads
  with the expected modules: Data Integration, Data Development, Data
  Architecture. \|
| Expected Result \| 1. Workspace is listed and accessible. 2. DataArts
  Studio console opens without errors. 3. All three modules (Data
  Integration, Data Development, Data Architecture) are visible in the
  navigation. \|
| Remarks \| If the workspace fails to load, check the Dayu instance
  status and the IAM role assignment. \|
| Test Result \| Pass \|

## TC-005: Verify data ingestion pipeline execution

  Field       Description
  ----------- ---------------------------------------------------
  Objective   Confirm that a DataArts Studio batch pipeline can

    successfully ingest CSV data from OBS, apply a basic transformation,
    and write the result to the target OBS path. |

| Prerequisites \| 1. TC-004 completed (DataArts Studio workspace
  accessible). 2. Source CSV file (customers.csv) exists in the OBS raw
  bucket. 3. Target OBS path (poc-datalake-curated/customers/) is
  configured. 4. Pipeline pl-ingest-customers is published in DataArts
  Studio. \|
| Procedure \| 1. In the DataArts Studio console, navigate to Data
  Development. 2. Locate the pipeline pl-ingest-customers in the job
  list. 3. Click Run to execute the pipeline. 4. Wait for the pipeline
  status to change to Success (timeout: 10 minutes). 5. Navigate to OBS
  and verify the output file exists in poc-datalake-curated/customers/.
  6. Download the output file and verify the row count matches the
  source (no data loss). \|
| Expected Result \| 1. Pipeline execution completes with status
  Success. 2. Output file is created in the target OBS path. 3. Row
  count of the output file matches the source file. \|
| Remarks \| Pipeline execution time varies with data volume. For the
  POC, the source file contains approximately 10,000 rows. \|
| Test Result \| Pass \|

## TC-006: Verify Spark SQL query on MRS cluster

  Field       Description
  ----------- -------------------------------------------------------
  Objective   Confirm that a Spark SQL query can be executed on the

    MRS cluster to read data from a Hive table and return correct
    results, validating the integration between MRS and the data lake. |

| Prerequisites \| 1. TC-001 completed (MRS cluster healthy). 2. Hive
  table poc_db.customers exists and contains data loaded by the
  ingestion pipeline. 3. SSH access to the MRS master node is
  configured. \|
| Procedure \| 1. SSH into the MRS master node. 2. Run the Spark SQL
  CLI: spark-sql --master yarn -{}-conf
  spark.sql.hive.convertMetastoreOrc=true -e "SELECT COUNT(\*) FROM
  poc_db.customers;" 3. Verify the returned count matches the expected
  row count (10,000). 4. Run a sample query to verify data integrity:
  spark-sql --master yarn -e "SELECT customer_id, name FROM
  poc_db.customers LIMIT 5;" 5. Confirm the query returns 5 rows with
  non-null values. \|
| Expected Result \| 1. COUNT(\*) returns 10,000. 2. The sample query
  returns 5 rows with valid customer_id and name values. \|
| Remarks \| If the Spark SQL CLI is not available, use the MRS Spark2x
  component's web UI to submit the query instead. \|
| Test Result \| Pass \|

# Changelog

**1.0.0**  *2026-09-12*

Initial version.

Added Platform Architecture test cases (TC-001 to TC-003).

Added Data Engineering test cases (TC-004 to TC-006).
