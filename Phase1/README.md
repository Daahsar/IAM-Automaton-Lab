IAM Automaton Lab — Phase 1



Overview

This repository contains Phase 1 of the IAM Automaton Lab, a structured Identity and Access Management automation framework built on Microsoft Entra ID and Microsoft Graph PowerShell.



This phase establishes the foundational identity layer for the lab environment, including standardized user and group definitions, deterministic provisioning workflows, and an Infrastructure-as-Code (IaC) approach to identity object lifecycle management.



Subsequent phases will extend this baseline into full lifecycle automation, governance, and CI/CD-driven identity operations.



Scope of Phase 1

Phase 1 delivers the core identity fabric required for all downstream automation.



1\. Infrastructure-as-Code Structure

A predictable, extensible directory layout for identity automation:



iac/

&#x20; definitions/

&#x20;   users.json

&#x20;   groups.json

&#x20; scripts/

&#x20;   Generate-Users.ps1

&#x20;   Generate-Groups.ps1

&#x20;   Import-Users.ps1



2\. Identity Object Definitions

\- User objects defined declaratively in JSON

\- Group objects defined declaratively in JSON

\- Consistent schema for attributes, naming conventions, and organizational metadata



3\. Automated Provisioning

Using Microsoft Graph PowerShell:

\- Bulk user creation

\- Group creation

\- Password profile assignment

\- Account enablement

\- Deterministic, repeatable provisioning from code



This ensures the environment can be rebuilt or extended without manual intervention.



Included Components



JSON Definitions

\- users.json — canonical user definitions for provisioning

\- groups.json — organizational group structure



Automation Scripts

\- Generate-Users.ps1 — produces structured user definitions

\- Generate-Groups.ps1 — produces group definitions

\- Import-Users.ps1 — provisions users into Entra ID using Graph API



Repository Hygiene

\- .gitignore included to maintain a clean and secure repository

\- Repository structured for future CI/CD integration



Prerequisites

\- Microsoft Entra ID tenant access

\- Microsoft Graph PowerShell module installed

\- Sufficient directory permissions (User.ReadWrite.All, Group.ReadWrite.All)

\- PowerShell 7 or later recommended



Execution Workflow



1\. Generate User Definitions

Run the Generate-Users.ps1 script.



2\. Generate Group Definitions

Run the Generate-Groups.ps1 script.



3\. Provision Users into Entra ID

Run the Import-Users.ps1 script.



The provisioning pipeline will create users with:

\- Display names

\- UPNs

\- Mail nicknames

\- Department and job title metadata

\- Password profiles

\- Enabled accounts



Phase 1 Deliverables

\- A reproducible identity baseline

\- Declarative user and group definitions

\- Automated provisioning pipeline

\- Version-controlled IaC structure

\- Foundation for advanced IAM automation



This phase establishes the authoritative source of identity objects for the lab environment.



Upcoming Work (Phase 2 and Beyond)

\- Automated group membership assignment

\- Licensing workflows

\- Dynamic group configuration

\- Onboarding and offboarding pipelines

\- Role and privilege assignments

\- Secrets management

\- CI/CD automation via GitHub Actions

\- Governance and compliance automation



Each phase builds on the previous to create a complete, enterprise-grade IAM automation ecosystem.

