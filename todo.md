API Test CURL:
curl -X GET "https://www.edukb.site/api/user/getparam" `
  -H "Authorization: Bearer XXXXX" `
  -H "x-cloudfront-secret: XXXXX"
====
- Design service and booking workings and update RDS tables if needed
    - done. below is a full description.
- Code FrontEnd User section. 
    - create user in cognito
    - join cognito with user table using "cognito_sub" parameter
    - follow user creation logic below
    - implement modify user (PUT)
- Code frontend Service section
- Code frontend Booking 

- continue with phase 9 and 10


- is there a resource without tags / default name?
- make network diagram of project and store in architecture folder and reference in architecture.md file
- user creation notes
    - create user in AWS Cognito
    - if successfully created
        - get "cognito_sub" returned from creation
        - create user in RDS with a additional field "cognito_sub" to relate both entities.
        - if successful
            - return user created
        - else
            - delete user from cognito
            - return user creation failure message
    - else return failure message


========================================
- Annotation: Lambda API's created:
    user
        POST   /user
        GET    /user/me
        PUT    /user/me

    service
        POST   /service
        GET    /service
        GET    /service/{id}
        PUT    /service/{id}
        DELETE /service/{id}

    booking
        POST   /booking
        GET    /booking
        PUT    /booking/{id}/status


==========================================

Web Application plan:

Web Application Plan
1. Login Page

Purpose

Authenticate with Cognito.

Flow

User clicks Login.
Redirect to Cognito Hosted UI.
After login, receive Authorization Code.
Exchange for JWT (PKCE).
Store access token.

APIs

None (Cognito only).
2. Home / Marketplace

Purpose

Show all available freelancer services.

Displays

Service cards
Title
Description
Price
Category
Freelancer name
Avatar

Actions

View service
Book service

API

GET /service
3. Service Details

Purpose

Show complete information about one service.

Displays

Service details
Portfolio images/files
Freelancer information
Price
Book button

Actions

Create booking

APIs

GET  /service/{id}
POST /booking
4. My Profile

Purpose

Show and edit logged user's information.

Displays

Name
Email
Bio
Skills
Avatar

Actions

Edit profile
Upload avatar

APIs

GET /user/me
PUT /user/me
5. My Services

Purpose

Manage services created by the logged user.

Displays

List of user's services

Actions

Create service
Edit service
Delete service

APIs

GET    /service
POST   /service
PUT    /service/{id}
DELETE /service/{id}
6. Create/Edit Service

Purpose

Create or modify a service.

Fields

Title
Description
Price
Category
Portfolio uploads

APIs

POST /service
PUT  /service/{id}
7. My Bookings

Purpose

Show bookings involving the logged user.

Displays

Service
Customer
Status
Date

Actions

Accept booking
Reject booking
Complete booking

APIs

GET /booking
PUT /booking/{id}/status
8. Booking Confirmation

Purpose

Show booking success.

Displays

Booking created
Current status
Notification that confirmation email will be sent asynchronously

API
None (already created by POST /booking)

Authentication

Every API call includes

Authorization: Bearer <JWT>

The frontend should:

detect expired tokens
redirect to login if needed
logout by clearing tokens and redirecting to Cognito logout

9. Phase 9 — S3 Integration
Avatar Upload

Instead of uploading through your backend:

User clicks Change Avatar.
Frontend requests a pre-signed upload URL.
Frontend uploads directly to S3.
Frontend calls
PUT /user/me

to save the avatar URL/key.

Advantages:

Lambda doesn't process file contents.
Faster uploads.
Lower cost.
Portfolio Upload

While creating or editing a service:

User selects one or more files.
Frontend requests one pre-signed URL per file.
Uploads directly to S3.
Saves the returned object keys in the service record.

Later:

GET /service/{id}

returns portfolio image/file URLs.

The page can display:

images
downloadable PDFs
other portfolio documents

10. Phase 10 — SQS & SNS Integration

The webpage never communicates directly with SQS or SNS.

Instead:

Browser
      ↓
API Gateway
      ↓
Lambda
      ↓
SQS / SNS

The frontend only triggers actions through normal REST APIs.

Booking Creation

User clicks

Book Service

Frontend calls

POST /booking

Backend then:

saves booking
publishes BookingCreated event
sends message to SQS
worker processes email
worker publishes SNS notification

Frontend immediately displays

Booking created successfully.
A confirmation email will be sent shortly.

No waiting for email.

Booking Status Change

Freelancer clicks

Accept

or

Reject

or

Complete

Frontend calls

PUT /booking/{id}/status

Backend:

updates database
publishes BookingStatusChanged event
queues notification
email Lambda sends email
SNS publishes notification

Frontend simply refreshes booking status.

Future Notification Page (Optional)

Later you could add:

Notifications

showing:

booking accepted
booking rejected
booking completed

This would come from notifications stored after SNS events.

Overall User Flow
Login
   │
   ▼
Marketplace
   │
   ├── View Service
   │       │
   │       ▼
   │   Service Details
   │       │
   │       ▼
   │   Create Booking
   │
   ├── My Profile
   │       │
   │       └── Upload Avatar (S3)
   │
   ├── My Services
   │       │
   │       ├── Create Service
   │       ├── Edit Service
   │       └── Upload Portfolio (S3)
   │
   └── My Bookings
           │
           └── Update Booking Status
Additional APIs Needed for Phase 9

To fully support direct S3 uploads, you'll typically add two endpoints (or one generic endpoint) that return pre-signed URLs:

POST /upload/avatar-url

Returns a pre-signed URL for uploading a profile avatar.

POST /upload/portfolio-url

Returns one or more pre-signed URLs for uploading portfolio files.

These endpoints do not upload files themselves—they only generate temporary upload URLs. The browser uploads directly to S3 using those URLs, then uses the existing PUT /user/me or POST/PUT /service endpoints to save the uploaded object keys. This is the AWS-recommended approach for web applications.