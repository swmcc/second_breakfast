# Authentication Specification

## Overview

The Authentication domain covers user registration, login, logout, and session management. Second Breakfast uses a simple session-based authentication system with bcrypt password hashing.

## Requirements

### User Data Model

#### REQ-AUTH-001: User Attributes
A User entity MUST have the following attributes:
- `email` (string, required, unique) - User's email address
- `password_digest` (string) - bcrypt-hashed password

#### REQ-AUTH-002: Password Security
The system MUST use `has_secure_password` (bcrypt) for password hashing.
- Raw passwords SHALL NOT be stored in the database
- Password verification MUST use bcrypt's secure comparison

### User Registration

#### REQ-AUTH-010: Registration Fields
The registration form MUST collect:
- Email address
- Password
- Password confirmation

#### REQ-AUTH-011: Email Uniqueness
The system MUST reject registration with a duplicate email address.

#### REQ-AUTH-012: Email Presence
The system MUST reject registration without an email address.

### User Login

#### REQ-AUTH-020: Login Credentials
The login form MUST accept:
- Email address
- Password

#### REQ-AUTH-021: Successful Login
Upon successful authentication:
- The user's ID SHALL be stored in the session
- The user SHALL be redirected to the root path
- A success notice SHALL be displayed

#### REQ-AUTH-022: Failed Login
Upon failed authentication:
- The session SHALL NOT contain a user ID
- The login form SHALL be re-rendered
- An alert message SHALL be displayed
- The response status SHALL be 422 (Unprocessable Entity)

### User Logout

#### REQ-AUTH-030: Logout Process
Upon logout:
- The user ID SHALL be removed from the session
- The user SHALL be redirected to the root path
- A success notice SHALL be displayed

### Session Management

#### REQ-AUTH-040: Current User Helper
The `current_user` helper method:
- SHALL return the authenticated User object when logged in
- SHALL return nil when not logged in
- MUST be available to all controllers and views

#### REQ-AUTH-041: Authentication Check Helper
The `user_signed_in?` helper method:
- SHALL return true when a user is logged in
- SHALL return false when no user is logged in
- MUST be available to all controllers and views

#### REQ-AUTH-042: Authentication Enforcement
The `authenticate_user!` method:
- SHALL redirect to the sign-in path if not authenticated
- SHALL display an alert message
- MUST be usable as a before_action filter

### Route Configuration

#### REQ-AUTH-050: Authentication Routes
The following routes MUST be available:
- `GET /sign_in` - Login form
- `POST /session` - Create session (login)
- `DELETE /sign_out` - Destroy session (logout)
- `GET /users/new` - Registration form
- `POST /users` - Create user (register)

## Scenarios

### Scenario: Successful User Registration

**Given** no user exists with email "new@example.com"
**When** a visitor submits the registration form with:
- Email: "new@example.com"
- Password: "securepassword"
- Password confirmation: "securepassword"
**Then** a new user SHALL be created
**And** the user's password SHALL be securely hashed
**And** the user MAY be redirected to sign in

### Scenario: Registration with Duplicate Email

**Given** a user exists with email "existing@example.com"
**When** a visitor attempts to register with email "existing@example.com"
**Then** the registration SHALL fail
**And** a validation error SHALL be displayed

### Scenario: Successful Login

**Given** a user exists with email "user@example.com" and password "password123"
**When** the user submits the login form with correct credentials
**Then** the user SHALL be logged in
**And** `current_user` SHALL return the user
**And** `user_signed_in?` SHALL return true
**And** the user SHALL be redirected to the homepage
**And** "Logged in successfully" SHALL be displayed

### Scenario: Login with Invalid Password

**Given** a user exists with email "user@example.com" and password "password123"
**When** someone submits the login form with:
- Email: "user@example.com"
- Password: "wrongpassword"
**Then** the login SHALL fail
**And** the session SHALL NOT contain a user ID
**And** "Invalid email or password" SHALL be displayed
**And** the login form SHALL be re-displayed

### Scenario: Login with Non-existent Email

**Given** no user exists with email "nobody@example.com"
**When** someone submits the login form with that email
**Then** the login SHALL fail
**And** "Invalid email or password" SHALL be displayed

### Scenario: Successful Logout

**Given** a user is logged in
**When** the user clicks sign out
**Then** the session SHALL be cleared
**And** `current_user` SHALL return nil
**And** `user_signed_in?` SHALL return false
**And** the user SHALL be redirected to the homepage
**And** "Logged out successfully" SHALL be displayed

### Scenario: Access Protected Resource While Logged Out

**Given** a visitor is not logged in
**When** the visitor attempts to create a new recipe
**Then** the visitor SHALL be redirected to the sign-in page
**And** "You must sign in first" SHALL be displayed

### Scenario: Access Protected Resource While Logged In

**Given** a user is logged in
**When** the user attempts to create a new recipe
**Then** the new recipe form SHALL be displayed
**And** the user SHALL NOT be redirected
