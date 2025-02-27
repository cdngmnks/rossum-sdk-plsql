CREATE OR REPLACE PACKAGE WEBCRM.ROSSUM_SDK AS

    -- global constants
    gc_base_url constant VARCHAR2(26) := 'https://api.elis.rossum.ai';
    gc_username constant VARCHAR2(27) := '<ROSSUM_USERNAME>';
    gc_password constant VARCHAR2(15) := '<ROSSUM_PASSWORD>';

    -- endpoints
    gc_login_url constant VARCHAR2(14) := '/v1/auth/login';
    gc_logout_url constant VARCHAR2(15) := '/v1/auth/logout';
    gc_uploads_url constant VARCHAR2(11) := '/v1/uploads';
    gc_annotations_url constant VARCHAR2(15) := '/v1/annotations';
    gc_export_url constant VARCHAR2(27) := '/v1/queues/{queueId}/export';
    gc_default_queue_id constant NUMBER := 123456;

    -- global variables
    gv_access_token CLOB;

    PROCEDURE login;
    PROCEDURE logout;

    FUNCTION create_upload_task ( p_queue_id     IN NUMBER DEFAULT rossum_sdk.gc_default_queue_id,
                                  p_file_name    IN VARCHAR2,
                                  p_file_blob    IN BLOB ) RETURN VARCHAR2;
    FUNCTION get_task_upload_url ( p_task_url IN VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION get_upload_annotation_url ( p_upload_url IN VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION create_annotation_embedded_url ( p_annotation_url IN VARCHAR2, 
                                              p_return_url     IN VARCHAR2, 
                                              p_cancel_url     IN VARCHAR2 ) RETURN VARCHAR2;
    FUNCTION get_annotation_export_json ( p_queue_id       IN NUMBER DEFAULT rossum_sdk.gc_default_queue_id,
                                          p_annotation_url IN VARCHAR2 ) RETURN JSON_OBJECT_T;

END ROSSUM_SDK;
/