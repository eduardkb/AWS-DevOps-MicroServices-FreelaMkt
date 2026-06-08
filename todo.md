- is there a resource without tags / default name?
- create webApp in Python Flask
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