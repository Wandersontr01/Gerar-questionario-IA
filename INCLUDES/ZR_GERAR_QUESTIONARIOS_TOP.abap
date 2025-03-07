*&---------------------------------------------------------------------*
*& Include          ZR_GERAR_QUESTIONARIOS_TOP
*&---------------------------------------------------------------------*
DATA: gs_quest_request  TYPE zst_quest_request,
      gs_quest_response TYPE zst_quest_response_questoes.

DATA: gt_list TYPE vrm_values.

DATA: go_cpi_conn TYPE REF TO zcl_cpi_connection_maintain,
      gv_ambiente TYPE string,
      gt_headers  TYPE tihttpnvp,
      gs_headers  TYPE ihttpnvp.

DATA: gv_erro TYPE string.

DATA: gv_nota TYPE int1.