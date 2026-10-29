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

\- Temporary Access Pass (TAP) issuance for first sign-in and onboarding — no hardcoded or shared passwords

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

\- Import-Users.ps1 — provisions users into Entra ID using Graph API and issues a Temporary Access Pass for each new user



Repository Hygiene

\- .gitignore included to maintain a clean and secure repository

\- Repository structured for future CI/CD integration

Security Note — Handling Credentials

This lab does not use hardcoded, shared, or distributed passwords. An earlier version of Import-Users.ps1 used a hardcoded temporary password for lab provisioning; that is not best practice for handling credentials in an enterprise environment, and it has been replaced.

Provisioning now uses a Microsoft Entra ID Temporary Access Pass (TAP) for onboarding:

\- No password is stored in the script, the documentation, or the repository, and no password is shared with the user.

\- Microsoft Graph requires a passwordProfile when an account is created, so the script generates a unique, cryptographically random value in memory for that creation step only. It is never displayed, logged, stored, shared, or used to sign in, and it is discarded immediately after the account is created.

\- The script then issues a one-time, time-limited Temporary Access Pass (default: 480 minutes, within the tenant TAP policy's minimum/maximum) for the new account. The TAP is returned only at creation, shown once to the operator for secure out-of-band delivery, and is used by the user to sign in for the first time, register MFA / a passwordless method, and set their own password if one will be used.

\- If TAP issuance fails, the script reports it and does not fall back to sharing a password. Check that the TAP authentication methods policy is enabled and covers the user, and that the session has the UserAuthenticationMethod.ReadWrite.All permission.

In an enterprise environment, passwords and other secrets should never be hardcoded in code, scripts, or documentation, and should never be committed to a public — or any — source code repository. Secrets that cannot be eliminated should be handled through an approved secrets management solution (for example, Azure Key Vault, CyberArk, or another enterprise vault), secure pipeline secrets, and managed identities where possible, with least-privilege access, logging, and regular rotation. Any credential that has been exposed in a repository should be treated as compromised and rotated immediately.


Prerequisites

\- Microsoft Entra ID tenant access

\- Microsoft Graph PowerShell module installed (including Microsoft.Graph.Identity.SignIns, for Temporary Access Pass creation)

\- Sufficient directory permissions (User.ReadWrite.All, Group.ReadWrite.All, UserAuthenticationMethod.ReadWrite.All)

\- Temporary Access Pass authentication methods policy enabled in the tenant and covering the provisioned users, with a permitted lifetime that includes the requested TAP lifetime (default 480 minutes)

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

\- A one-time, time-limited Temporary Access Pass for first sign-in and onboarding (shown once, at creation only)

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

