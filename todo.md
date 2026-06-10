- on alb and functions validate host header being the domain. so that clients can't access cloudfront directly.
- test if cloudfront is exclusive. can I access API Gatewway or ALB?
- remove default URL from cloudfront?
- is there a resource without tags / default name?
- create cognito user pool and auth settings with TF.
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
        PUT    /booking/{id}/status4