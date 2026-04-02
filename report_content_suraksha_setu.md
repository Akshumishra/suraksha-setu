# Suraksha Setu Report Content Draft

Use this file as a draft for `Report_Format__2025_26.docx`.

Replace these placeholders before submission:
- `[Mentor Name]`
- `[Coordinator Name]`
- `[Student 1 Name, Roll No.]`
- `[Student 2 Name, Roll No.]`
- `[Student 3 Name, Roll No.]`
- `[Student 4 Name, Roll No.]`
- `[Semester]`
- `[Testing Tools Used]`
- `[GitHub Link]`

Suggested project title:

**Suraksha Setu: Smart SOS and Emergency Response System**

## Certificate

This is to certify that **[Student Name(s)]**, student(s) of **B.Tech. (Information Technology), Semester [Semester]**, have successfully completed the project report entitled **"Suraksha Setu: Smart SOS and Emergency Response System"** under my guidance and supervision. The work presented in this report is original and has been carried out during the academic session **2025-2026** in the Department of Information Technology, Swami Keshvanand Institute of Technology, Management and Gramothan, Jaipur.

Mentor: **[Mentor Name]**  
Coordinator: **[Coordinator Name]**

## Declaration

We hereby declare that the project report entitled **"Suraksha Setu: Smart SOS and Emergency Response System"** is a record of original work carried out by us under the guidance of **[Mentor Name]** and the coordination of **[Coordinator Name]**. This report is submitted in partial fulfillment of the requirements for the award of the degree of **Bachelor of Technology in Information Technology**. To the best of our knowledge, this work has not been submitted elsewhere for the award of any other degree, diploma, or certificate.

Team Members:
- `[Student 1 Name, Roll No.]`
- `[Student 2 Name, Roll No.]`
- `[Student 3 Name, Roll No.]`
- `[Student 4 Name, Roll No.]`

## Acknowledgement

We express our sincere gratitude to our project mentor **[Mentor Name]** for constant guidance, encouragement, and valuable suggestions throughout the development of this project. We are also thankful to our project coordinator **[Coordinator Name]** for continuous support during planning, execution, and documentation. We extend our thanks to the Head of Department, faculty members, and management of SKIT M&G, Jaipur for providing the academic environment and resources required to complete this work successfully. Finally, we thank our friends and family members who directly or indirectly supported us throughout the project.

## Abstract

Suraksha Setu is a smart personal safety and emergency response system designed to provide rapid assistance during critical situations. The project integrates a Flutter-based mobile application, a police response dashboard, Firebase backend services, and Cloudinary-powered multimedia upload to create a complete SOS management platform. Through the mobile application, users can register, maintain their safety profile, add emergency contacts, and trigger an SOS either from the app interface or through volume-button based activation. Once an SOS is triggered, the system creates a live incident record, captures emergency multimedia evidence, uploads video and audio files to Cloudinary for secure cloud storage, and continuously updates the user's real-time location. The system also identifies the nearest police station using geographic coordinates and station jurisdiction data. Linked emergency contacts receive instant alerts, and an SMS fallback mechanism is used in low-connectivity conditions. On the responder side, the police dashboard allows approved police personnel and administrators to monitor active incidents, inspect victim details, review location and media evidence, update case status, and analyze SOS trends. By combining mobile sensing, location intelligence, cloud storage, real-time databases, and responder workflows, Suraksha Setu offers a practical and scalable solution to improve emergency communication, incident tracking, and public safety response.

## Chapter 1: Introduction

### 1.1 Problem Statement and Objective

In many emergency situations, victims are unable to place a normal phone call or explain their condition in time. Delays in sharing accurate location, identity, and supporting evidence reduce the effectiveness of emergency response. Traditional panic systems often stop at a simple alert and do not provide live tracking, proof of incident, or structured police coordination.

The objective of Suraksha Setu is to develop an end-to-end emergency response system that enables users to send immediate SOS alerts, share live location, upload multimedia evidence, and notify both trusted contacts and police stations through a coordinated digital platform.

### 1.2 Objectives

- To provide a mobile-based SOS system for rapid emergency triggering.
- To support multiple SOS activation methods, including app-based and volume-button based triggering.
- To capture and upload multimedia evidence to Cloudinary.
- To continuously update live location and assign the nearest police station.
- To notify linked emergency contacts and enable SMS fallback when internet is unavailable.
- To provide a police dashboard for monitoring, accepting, and resolving SOS cases.
- To provide an admin interface for station registration, police approval requests, and SOS analytics.

### 1.3 Literature Survey / Market Survey / Investigation and Analysis

Existing safety applications usually focus on isolated features such as panic-button activation, contact notification, or live location sharing. However, many solutions do not provide integrated police-side incident handling, structured evidence management, or low-connectivity fallback support. Our investigation showed that there is a clear need for a connected platform where user-side SOS activation, emergency-contact alerts, media preservation, and police response management are all part of a single workflow. Suraksha Setu was designed to address this gap.

### 1.4 Introduction to Project

Suraksha Setu is a full-stack emergency support platform consisting of a user-facing mobile application, a police/admin dashboard, and a cloud backend. The mobile app handles authentication, permissions, emergency contacts, SOS triggering, location tracking, and SOS history. The dashboard supports police response, case review, admin approval, station registration, and analytics. Firebase provides authentication, data storage, security rules, and server-side logic, while Cloudinary stores multimedia evidence captured during emergencies.

### 1.5 Proposed Logic / Algorithm / Solution

1. The user registers and logs in to the mobile application.
2. The user grants required permissions such as location, camera, microphone, SMS, and notifications.
3. The user adds trusted emergency contacts.
4. An SOS is triggered either from the app UI or from the volume-button gesture.
5. A new SOS document is created with timestamp, trigger source, and active status.
6. The current location is fetched and the nearest police station is assigned using station coordinates and jurisdiction radius.
7. Emergency contacts receive in-app alerts, and SMS fallback is triggered if internet is unavailable.
8. Multimedia evidence is captured and uploaded to Cloudinary. If immediate upload fails, background sync retries later.
9. Police officers review the case in the dashboard, inspect details, and update the case from active to accepted and then resolved.
10. Administrators monitor SOS analytics and manage station and police onboarding workflows.

### 1.6 Scope of the Project

The scope of Suraksha Setu includes Android-based emergency support, live location tracking, emergency contact management, SOS history, multimedia evidence upload, nearest-station assignment, police case handling, admin oversight, and role-based dashboard access. The current scope does not include nationwide helpline integration, AI-based incident prediction, or a fully mature iOS background SOS workflow.

## Chapter 2: Software Requirement Specification

### 2.1 Overall Description

Suraksha Setu is a mobile and dashboard-based emergency response system intended to connect users, emergency contacts, police stations, and administrators on one digital platform. It supports user registration, permission handling, SOS triggering, live location sharing, evidence upload, emergency contact alerting, station assignment, police response tracking, and incident closure.

### 2.2 Product Perspective

The system is composed of:
- A Flutter mobile application for users.
- A Flutter-based police/admin dashboard.
- Firebase Authentication for user-role management.
- Cloud Firestore for storing users, contacts, SOS cases, alerts, and police data.
- Firebase Cloud Functions for secure police onboarding and status transitions.
- Cloudinary for multimedia upload and retrieval.

### 2.3 System Interfaces

The system interacts with:
- Smartphone hardware for location, camera, microphone, and SMS support.
- Firestore for real-time incident and profile data.
- Cloudinary Upload API for storing video and audio evidence.
- Firebase Functions for backend-controlled operations.
- Android foreground and accessibility services for SOS execution in background-oriented scenarios.

### 2.4 User Interfaces

The mobile application provides onboarding, login, signup, permission setup, SOS action, emergency contacts, alerts, and SOS history interfaces. The police/admin dashboard provides police login, registration requests, assigned-case monitoring, case detail screens, station registration, and admin analysis views. The interfaces are designed for fast navigation and quick visibility of emergency status.

### 2.5 Hardware Interfaces

The main hardware interfaces are:
- GPS for live location tracking
- Camera for visual emergency recording
- Microphone for audio capture
- Volume buttons for gesture-based SOS trigger
- SIM/SMS capability for fallback alerting
- Internet connectivity for cloud sync and dashboard updates

### 2.6 Software Interfaces

The project integrates with Flutter SDK, Firebase SDKs, Cloudinary APIs, and Android platform services. Data communication mainly occurs through HTTPS and Firestore listeners.

### 2.7 Communication Interfaces

Communication in the system includes:
- HTTPS requests to Firebase and Cloudinary
- Firestore snapshot updates for live dashboard data
- SMS transmission during fallback mode
- Notifications shown during SOS processing

### 2.8 Memory Constraints

The system temporarily stores captured media on the device before upload. Therefore, sufficient local storage is required for short recordings. Firestore stores structured metadata, while Cloudinary stores larger multimedia files to reduce database load.

### 2.9 Operations

Major operations are:
- User registration and login
- Permission management
- SOS trigger and cancellation
- Live location write/update
- Emergency contact alert generation
- Multimedia upload and retry sync
- Police case acceptance and resolution
- Admin approval and station management

### 2.10 Project Functions

Core functions include:
- User profile management
- Emergency contact CRUD operations
- SOS trigger from UI or hardware gesture
- Incident creation and live tracking
- Cloudinary multimedia upload
- Station assignment based on location
- Contact alerting and SMS fallback
- Dashboard-based police response
- Admin analysis and police onboarding

### 2.11 User Characteristics

The system serves four main user groups:
- General users seeking emergency support
- Emergency contacts linked to a user account
- Police personnel handling assigned incidents
- Administrators managing stations and approvals

Basic smartphone knowledge is sufficient for user-side operation, while police and admin users require familiarity with dashboard-based case handling.

### 2.12 Constraints

The project is constrained by mobile permissions, GPS availability, Android background restrictions, internet quality, SMS/network carrier support, and cloud-service quotas. Performance of real-time features also depends on device capabilities and connectivity conditions.

### 2.13 Assumptions and Dependencies

The project assumes that users have Android devices with camera, microphone, location, and SMS support; that station coordinates are correctly registered; and that Firebase and Cloudinary credentials are properly configured.

## Chapter 3: System Design Specification

### 3.1 System Architecture

Suraksha Setu follows a client-cloud-dashboard architecture.

1. **Mobile Client Layer**  
   The Flutter mobile app manages authentication, permissions, emergency contacts, SOS triggering, local storage, and SOS history.

2. **Device Service Layer**  
   Android foreground and accessibility services handle volume-button based triggering, notifications, live location updates, media recording coordination, and SMS fallback.

3. **Cloud Backend Layer**  
   Firebase Authentication manages roles. Firestore stores user, contact, SOS, alert, and station data. Cloud Functions enforce secure police approval and case-status transition logic.

4. **Media Layer**  
   Cloudinary stores uploaded emergency media and returns secure URLs for evidence review.

5. **Police/Admin Dashboard Layer**  
   The dashboard displays active cases, analytics, station queues, case details, and administrative actions.

### 3.2 Module Decomposition Description

The system is divided into the following modules:
- Mobile authentication and onboarding module
- Permission management module
- SOS trigger and background-service module
- Live location and station-assignment module
- Emergency contacts and alert module
- Cloudinary media-upload and retry-sync module
- Police dashboard module
- Admin approval and station-management module
- Firebase backend and security-rules module

### 3.3 High-Level Design Diagrams

Insert the following diagrams in the report:

### 3.3.1 Use Case Diagram

Actors:
- User
- Emergency Contact
- Police Officer
- Admin

Use cases:
- Register/Login
- Grant Permissions
- Add Emergency Contacts
- Trigger SOS
- Cancel SOS
- View Alerts and History
- Monitor Assigned Cases
- View Case Details
- Update Case Status
- Approve/Reject Police Request
- Register Police Station

Suggested caption: **Figure 3.1: Use Case Diagram of Suraksha Setu**

### 3.3.2 Activity Diagram

Suggested flow:
- User opens app
- User authenticates
- User grants permissions
- User triggers SOS
- App creates incident
- App captures location
- App assigns nearest station
- App alerts contacts
- App uploads media to Cloudinary
- Dashboard receives updates
- Police accepts and resolves case

Suggested caption: **Figure 3.2: Activity Diagram for SOS Handling**

### 3.3.3 Data Flow Diagram

External entities:
- User
- Emergency Contact
- Police Dashboard
- Admin
- Cloudinary

Data stores:
- Users
- Emergency Contacts
- SOS Cases
- Police Stations
- Registration Requests
- Incoming SOS Alerts

Suggested caption: **Figure 3.3: Data Flow Diagram of the Proposed System**

### 3.3.4 E-R Diagram

Suggested entities:
- User
- EmergencyContact
- SOS
- IncomingSOS
- PoliceStation
- PoliceRegistrationRequest

Suggested relationships:
- One user can have many emergency contacts.
- One user can create many SOS cases.
- One SOS can be assigned to one police station.
- One SOS can generate many alerts.

### 3.3.5 Class Diagram

Suggested classes from the implementation:
- `SosService`
- `SosRepository`
- `SosSyncService`
- `EmergencyContactService`
- `SosAlertService`
- `StationAssignmentService`
- `PoliceAuthService`
- `SosDashboardService`
- `SosCase`
- `EmergencyContact`
- `SosAlert`
- `PoliceStation`

Suggested caption: **Figure 3.4: Class Diagram of Suraksha Setu**

### 3.3.6 Other Diagrams

For the Communication Diagram, Sequence Diagram, Component Diagram, Deployment Diagram, and Business Process Model, use the same workflow:
- User triggers SOS
- Mobile app/service creates case
- Location and contacts are processed
- Cloudinary stores media
- Firestore updates dashboard
- Police acts on case
- Admin monitors the system

## Chapter 4: Methodology and Team

### 4.1 Introduction to Process Model

The development of Suraksha Setu follows the Waterfall model because the project requirements were identified and executed in a structured sequence. First, the team studied the problem of delayed emergency response and defined project requirements. Next, the architecture, database entities, and interfaces were designed. After this, the mobile app, dashboard, backend services, and media-upload flow were implemented. Finally, all modules were integrated, tested, and documented.

The major phases followed were:
- Requirement gathering and analysis
- System design
- Implementation
- Integration and testing
- Deployment and maintenance

### 4.2 Waterfall Model Pros and Cons in This Project

Advantages:
- Clear project planning and documentation
- Easy task distribution among team members
- Suitable for academic project reporting
- Better phase-wise tracking of UI, backend, and testing work

Disadvantages:
- Late requirement changes are difficult to incorporate
- Mobile permission and background behavior often need repeated adjustments
- Real-world emergency workflows may evolve after user testing

### 4.3 Team Members, Roles and Responsibilities

Replace with your actual team details:

- `[Student 1 Name]` - Mobile app, onboarding, authentication, and permissions.
- `[Student 2 Name]` - SOS workflow, location tracking, Cloudinary/media sync, and Android service logic.
- `[Student 3 Name]` - Police dashboard, case handling, and analytics.
- `[Student 4 Name]` - Firebase backend, security rules, documentation, and testing.

## Chapter 5: Centering System Testing

### 5.1 Introduction

The Suraksha Setu system was tested at different levels to verify correctness, reliability, integration, usability, and performance. Since the project handles emergency scenarios, special attention was given to SOS triggering, live location updates, station assignment, Cloudinary media upload, contact notifications, and police-side case visibility.

### 5.2 Functionality Testing

The following areas were tested:
- Registration and login
- Permission validation
- Emergency contact management
- SOS trigger from app UI
- Volume-button based SOS trigger
- Firestore SOS creation
- Live location updates
- Cloudinary multimedia upload
- Dashboard visibility of assigned cases
- Police case acceptance and resolution
- Admin approval and station registration

### 5.3 Unit Testing

Unit-level verification was applied to services such as emergency contact management, SOS repository logic, station assignment, media upload logic, and dashboard data parsing. Input validation, exception handling, and field-level data mapping were checked in individual modules.

### 5.4 Integration Testing

Integration testing focused on:
- Mobile app with Firebase Authentication
- Mobile app with Firestore
- SOS service with Cloudinary upload
- SOS creation with dashboard visibility
- Police dashboard with Cloud Functions status updates
- Admin approval flow with police-account creation

### 5.5 System Testing

System testing validated the full end-to-end workflow from user onboarding to final case resolution. The team tested registration, permission granting, emergency-contact addition, SOS triggering, location capture, case assignment, dashboard visibility, police acceptance, and closure reporting.

### 5.6 Database Testing

Database testing verified:
- Correct storage of user profiles
- Creation and update of emergency contacts
- Proper structure of SOS documents
- Assignment of station IDs based on location
- Creation of incoming SOS alerts
- Controlled status transitions and resolution fields

### 5.7 Performance Testing

Performance testing was performed by observing the response time of SOS case creation, live location updates, dashboard refresh, and multimedia upload initiation. Since media files are uploaded to Cloudinary instead of directly storing binary data in Firestore, the system reduces database overhead and improves maintainability. Performance varies with network quality, GPS availability, and device hardware, but the design allows deferred sync when connectivity is unstable.

### 5.8 Usability Testing

Usability testing focused on clarity, quick action, and stress-friendly interaction. The mobile app uses simple navigation and prominent SOS controls, while the dashboard prioritizes active incidents and displays essential information such as victim details, location freshness, and evidence status. The interface was designed to reduce confusion and support fast decision-making.

### 5.9 Tools Used for Testing

Replace this line with your real tools:

`[Testing Tools Used: Example - Flutter debug build, Android device testing, Firebase Console, browser-based dashboard testing, manual validation logs]`

## Chapter 6: Test Execution Summary

### 6.1 Summary

Fill the final execution result after your last complete test run:

- Total test cases generated: 20
- Passed test cases: `[Fill after execution]`
- Failed test cases: `[Fill after execution]`
- Blocked test cases: `[Fill after execution]`
- Overall status: `[Pass / Pass with minor issues / Needs improvement]`

### 6.2 Suggested Test Cases

Fill the `Status` column after actual execution.

| Test Case ID | Module | Test Scenario | Expected Result | Status |
| --- | --- | --- | --- | --- |
| TC-01 | Authentication | Register with valid details | User account is created |  |
| TC-02 | Authentication | Log in with valid credentials | User is logged in successfully |  |
| TC-03 | Authentication | Log in with wrong password | Error message is shown |  |
| TC-04 | Permissions | Grant all required permissions | App allows continuation |  |
| TC-05 | Contacts | Add emergency contact | Contact is saved and visible |  |
| TC-06 | Contacts | Add own account as contact | Validation error is shown |  |
| TC-07 | SOS Trigger | Trigger SOS using app button | SOS case is created |  |
| TC-08 | SOS Trigger | Trigger SOS using volume buttons | Background SOS flow starts |  |
| TC-09 | SOS Cancellation | Cancel active SOS in time window | SOS is marked cancelled |  |
| TC-10 | Location | Trigger SOS with GPS enabled | Live location is stored |  |
| TC-11 | Station Assignment | Trigger SOS near a station | Nearest station is assigned |  |
| TC-12 | Alerts | Trigger SOS with linked contact accounts | Incoming alert is created |  |
| TC-13 | SMS Fallback | Trigger SOS without internet | SMS fallback is attempted |  |
| TC-14 | Media Capture | Record emergency media | Local file and metadata are created |  |
| TC-15 | Cloudinary | Upload media with internet | Media URL is stored |  |
| TC-16 | Sync | Restore internet after failed upload | Pending media sync succeeds |  |
| TC-17 | Police Dashboard | Open assigned station dashboard | Active cases are visible |  |
| TC-18 | Police Action | Accept active case | Status changes to accepted |  |
| TC-19 | Police Resolution | Resolve accepted case with report | Status changes to resolved |  |
| TC-20 | Admin Module | Approve police registration request | Request and station records update correctly |  |

## Chapter 7: Project Screenshots

Capture screenshots from the final working build and insert them with captions such as:

1. Figure 7.1: Onboarding Screen of Suraksha Setu
2. Figure 7.2: Login Screen
3. Figure 7.3: Signup and Safety Profile Screen
4. Figure 7.4: Permission Setup Screen
5. Figure 7.5: Home Screen with SOS Trigger
6. Figure 7.6: Emergency Contacts Screen
7. Figure 7.7: SOS Alerts Screen
8. Figure 7.8: SOS History Screen
9. Figure 7.9: Police Login / Registration Request Screen
10. Figure 7.10: Police Response Dashboard
11. Figure 7.11: SOS Case Detail with Location and Evidence
12. Figure 7.12: Admin SOS Analysis / Station Registration Screen

## Chapter 8: Conclusion and Future Scope

### 8.1 Conclusion

Suraksha Setu demonstrates a practical emergency response solution that combines mobile safety features, cloud-based coordination, and responder-side case management in one integrated platform. The system allows users to trigger SOS alerts quickly, share live location, upload multimedia evidence through Cloudinary, notify trusted contacts, and route incidents to the nearest police station. The police dashboard and admin modules strengthen operational visibility by supporting station management, role-based access, case review, and closure reporting. Overall, the project addresses an important real-world problem and shows how Flutter, Firebase, Cloudinary, and Android system services can be combined to build a scalable and socially meaningful safety application.

### 8.2 Future Scope

Possible future enhancements are:
- Integration with government emergency helplines
- Push notifications for police and contacts
- Voice-activated SOS trigger
- AI-based risk detection and incident scoring
- Real-time map route guidance for responders
- Stronger iOS support for emergency workflows
- Multilingual support and wider accessibility features

## Chapter 9: UN Sustainable Development Goals Mapping

### 9.1 Mapping with UN SDGs

| SDG Goal | Relevance to Suraksha Setu |
| --- | --- |
| SDG 3: Good Health and Well-Being | Supports rapid emergency assistance and public well-being. |
| SDG 5: Gender Equality | Can be used as a practical safety tool, especially for women and vulnerable users. |
| SDG 9: Industry, Innovation and Infrastructure | Uses mobile and cloud technology to solve a real public-safety problem. |
| SDG 11: Sustainable Cities and Communities | Contributes to safer and more responsive communities. |
| SDG 16: Peace, Justice and Strong Institutions | Strengthens structured and accountable emergency-response workflows. |

## GitHub Link

Link: `[GitHub Link]`

## References

Use or adapt the following references in IEEE style:

[1] Flutter, "Flutter documentation," Available: https://docs.flutter.dev/  
[2] Firebase, "Cloud Firestore documentation," Available: https://firebase.google.com/docs/firestore  
[3] Firebase, "Cloud Functions for Firebase documentation," Available: https://firebase.google.com/docs/functions  
[4] Firebase, "Firebase Authentication documentation," Available: https://firebase.google.com/docs/auth  
[5] Cloudinary, "Cloudinary documentation," Available: https://cloudinary.com/documentation  
[6] Android Developers, "Android developer documentation," Available: https://developer.android.com/  
[7] United Nations, "Goal 5: Gender Equality," Available: https://sdgs.un.org/goals/goal5  
[8] United Nations, "Sustainable Development Goals," Available: https://sdgs.un.org/

## Final Checklist

- Replace all placeholder names and roll numbers
- Insert actual diagrams
- Insert final screenshots
- Update test-case status values
- Add your GitHub repository link
- Generate Table of Contents in Word
- Attach plagiarism report and research paper pages if required
