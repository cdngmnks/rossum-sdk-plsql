CREATE OR REPLACE PACKAGE BODY WEBCRM.ROSSUM_SDK AS

    -- https://elis.rossum.ai/api/docs/#login
    PROCEDURE login IS
        v_request_url VARCHAR2(255) := gc_base_url || gc_login_url;
        v_request JSON_OBJECT_T := JSON_OBJECT_T ();
        v_response CLOB;
        v_json JSON_OBJECT_T;
    BEGIN

        -- generate request payload
        v_request.put ( 'username', gc_username );
        v_request.put ( 'password', gc_password );

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Content-Type',
            p_value_01       => 'application/json',
            p_reset          => true );

        -- make request
        v_response := apex_web_service.make_rest_request ( p_url => v_request_url,
                                                           p_http_method => 'POST',
                                                           p_body => v_request.to_clob );

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- set global access token
        gv_access_token := v_json.get_string ( 'key' );

    END login;

    -- https://elis.rossum.ai/api/docs/#logout
    PROCEDURE logout IS
        v_request_url VARCHAR2(255) := gc_base_url || gc_logout_url;
        v_response CLOB;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_reset          => true );

        -- make request
        v_response := apex_web_service.make_rest_request ( p_url => v_request_url,
                                                           p_http_method => 'POST' );

        -- clear global access token
        gv_access_token := NULL;

    END logout;

    -- https://elis.rossum.ai/api/docs/#create-upload
    FUNCTION create_upload_task (p_queue_id      IN NUMBER DEFAULT rossum_sdk.gc_default_queue_id,
                                 p_file_name     IN VARCHAR2,
                                 p_file_blob     IN BLOB
    ) RETURN VARCHAR2 IS
        v_request_url VARCHAR2(255) := gc_base_url || gc_uploads_url || '?queue=' || to_char(p_queue_id);
        v_multipart apex_web_service.t_multipart_parts;
        v_response CLOB;
        v_json JSON_OBJECT_T;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_reset          => true );

        -- add file to multipart
        apex_web_service.append_to_multipart (
                p_multipart => v_multipart,
                p_name      => 'content',
                p_filename  => p_file_name,
                p_body_blob => p_file_blob );

        -- make request
        v_response  := apex_web_service.make_rest_request( p_url => v_request_url,
                                                           p_http_method => 'POST',
                                                           p_body_blob => apex_web_service.generate_request_body(v_multipart) );

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- return task url
        RETURN v_json.get_string ( 'url' );

    END create_upload_task;

    --https://elis.rossum.ai/api/docs/#task
    FUNCTION get_task_upload_url (p_task_url IN VARCHAR2) RETURN VARCHAR2 IS
        v_task_url VARCHAR2(255) := p_task_url || '?no_redirect=true';
        v_response CLOB;
        v_json JSON_OBJECT_T;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_reset          => true );

        -- make request
        v_response := apex_web_service.make_rest_request( p_url => v_task_url,
                                                          p_http_method => 'GET' );

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- return upload url
        return v_json.get_string ( 'result_url' );

    END get_task_upload_url;

    --https://elis.rossum.ai/api/docs/#retrieve-upload
    FUNCTION get_upload_annotation_url ( p_upload_url IN VARCHAR2 ) RETURN VARCHAR2 IS
        v_response CLOB;
        v_json JSON_OBJECT_T;
        v_array JSON_ARRAY_T;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_reset          => true );

        -- make request
        v_response := apex_web_service.make_rest_request( p_url => v_upload_url,
                                                          p_http_method => 'GET' );

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- return annotation url
        v_array := v_json.get_array ( 'annotations' );
        RETURN v_array.get_string ( 0 );

    END get_upload_annotation_url;

    --https://elis.rossum.ai/api/docs/#create-embedded-url-for-annotation
    FUNCTION create_annotation_embedded_url ( p_annotation_url IN VARCHAR2, 
                                              p_return_url IN VARCHAR2, 
                                              p_cancel_url IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_request_url VARCHAR2(255) := p_annotation_url || '/create_embedded_url';
        v_request JSON_OBJECT_T := JSON_OBJECT_T ();
        v_response CLOB;
        v_json JSON_OBJECT_T;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_name_02        => 'Content-Type',
            p_value_02       => 'application/json',
            p_reset          => true );

        -- generate request
        v_request.put ('return_url', p_return_url);
        v_request.put ('cancel_url', p_cancel_url);

        -- make request
        v_response  := apex_web_service.make_rest_request(
                               p_url => v_request_url,
                               p_http_method => 'POST',
                               p_body => v_request.to_clob);

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- return embedded url
        RETURN v_json.get_string ( 'url' );

    END create_annotation_embedded_url;

    --https://elis.rossum.ai/api/docs/#export-annotations
    FUNCTION get_annotation_export_json ( p_queue_id       IN NUMBER DEFAULT rossum_sdk.gc_default_queue_id,
                                          p_annotation_url IN VARCHAR2
    ) RETURN JSON_OBJECT_T IS
        v_request_url VARCHAR2(255) := gc_base_url || replace(gc_export_url, '{queueId}', to_char(p_queue_id));
        v_parm_names apex_application_global.VC_ARR2;
        v_parm_values apex_application_global.VC_ARR2;
        v_response CLOB;
        v_json JSON_OBJECT_T;
    BEGIN

        -- set request headers
        apex_web_service.set_request_headers(
            p_name_01        => 'Authorization',
            p_value_01       => 'Bearer ' || gv_access_token,
            p_reset          => true );

        -- set request parameters
        v_parm_names(1) := 'format';
        v_parm_values(1) := 'json';
        v_parm_names(2) := 'id';
        v_parm_values(2) := regexp_substr( p_annotation_url, '\d+$');

        -- make request
        v_response := apex_web_service.make_rest_request(
                                p_url => v_request_url,
                                p_http_method => 'GET',
                                p_parm_name => v_parm_names,
                                p_parm_value => v_parm_values);

        -- parse response
        v_json := JSON_OBJECT_T.parse ( v_response );

        -- return JSON object
        RETURN v_json;

    END get_annotation_export_json;

END ROSSUM_SDK;
/