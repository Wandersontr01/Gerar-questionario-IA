*&---------------------------------------------------------------------*
*& Include          ZR_GERAR_QUESTIONARIOS_F01
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& Form f_modify_values_listbox
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_modify_values_listbox.
  CASE sy-ucomm.
    WHEN 'CLEAR'.
      FREE: p_qtdeVf, p_qtdeOb, p_total.
    WHEN 'SEND' OR 'RESPONDE' OR 'RESPONDE2'.
      LEAVE TO SCREEN 0.
    WHEN 'RESPONDE'.
      sy-ucomm = 'CRET'.
  ENDCASE.

  IF p_total IS NOT INITIAL AND p_qtdeob IS INITIAL AND p_qtdeVf IS INITIAL.
    DO p_total TIMES.
      APPEND VALUE #( key = sy-index ) TO gt_list.
    ENDDO.

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'p_qtdeOb'
        values = gt_list.

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'p_qtdeVf'
        values = gt_list.

  ENDIF.

  IF p_qtdeob IS NOT INITIAL.
    APPEND VALUE #( key = p_total - p_qtdeOb ) TO gt_list.

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'p_qtdeVf'
        values = gt_list.
  ENDIF.

  IF p_qtdeVf IS NOT INITIAL.
    APPEND VALUE #( key = p_total - p_qtdeVf ) TO gt_list.

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'p_qtdeOb'
        values = gt_list.
  ENDIF.
  FREE gt_list.

ENDFORM. "f_modify_values_listbox

*&---------------------------------------------------------------------*
*& Form f_insert_values_listbox
*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_insert_values_listbox.
  p_send  = 'Gerar'.
  p_clear = 'Limpar quantidades'.
  p_resp  = 'Responder'.
  p_resp2 = 'Responder'.


  "Incrementa valores no listbox com opções de 1 a 10
  DO 10 TIMES.
    APPEND VALUE #( key = sy-index ) TO gt_list.
  ENDDO.

  "Chama a função para inserir os valores de 1 a 10 como opções no parametro
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'P_TOTAL'
      values = gt_list.

  FREE gt_list.
ENDFORM. "f_insert_values_listbox

*&---------------------------------------------------------------------*
*& Form f_estrutura_request
*&---------------------------------------------------------------------*
*& Função para estruturar o JSON para realizar a requisição
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_estrutura_request.
  FREE gs_quest_request.
  CONDENSE: p_materi,
            p_assunt,
            p_total,
            p_qtdeOb,
            p_qtdevf.

  gs_quest_request-materia   =  p_materi.

  gs_quest_request-assunto   = p_assunt.
  CASE p_nivel.
    WHEN 'F'.
      gs_quest_request-nivel     = 'Fundamental'.
    WHEN 'M'.
      gs_quest_request-nivel     = 'Médio'.
    WHEN 'S'.
      gs_quest_request-nivel     = 'Superior'.
    WHEN OTHERS.
  ENDCASE.

  PACK p_total TO gs_quest_request-tot_quest.
  CONDENSE gs_quest_request-tot_quest NO-GAPS.

  APPEND INITIAL LINE TO gs_quest_request-tipo_quest ASSIGNING FIELD-SYMBOL(<fs_tipo_quest>).
  PACK p_qtdeOb TO <fs_tipo_quest>-qtd_quest.
  CONDENSE <fs_tipo_quest>-qtd_quest NO-GAPS.
  <fs_tipo_quest>-tipo_quest = 'Objetiva'.

  APPEND INITIAL LINE TO gs_quest_request-tipo_quest ASSIGNING <fs_tipo_quest>.
  PACK p_qtdevf TO <fs_tipo_quest>-qtd_quest.
  CONDENSE <fs_tipo_quest>-qtd_quest NO-GAPS.
  <fs_tipo_quest>-tipo_quest = 'Verdadeiro ou Falso'.

ENDFORM. "f_estrutura_request

*&---------------------------------------------------------------------*
*& Form f_gera_questionario
*&---------------------------------------------------------------------*
*& Função para fazr a requisição no CPI e receber o retorno
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_gera_questionario.

  /ui2/cl_json=>serialize( EXPORTING data         = gs_quest_request
                                     pretty_name  = /ui2/cl_json=>pretty_mode-low_case
                           RECEIVING r_json       = DATA(lv_json)
                          ).

*-----------------------------------------------------------------------------------------*
*   02 Instanciar a classe
*-----------------------------------------------------------------------------------------*

  go_cpi_conn = NEW zcl_cpi_connection_maintain( iv_body    = lv_json
                                                 iv_path    = |/CPI/PROJETO4/CALL-API|
                                                 iv_method  = 'POST' ).

*-----------------------------------------------------------------------------------------*
*   03 Executa a classe para receber o retorno
*-----------------------------------------------------------------------------------------*
  go_cpi_conn->execution(
    IMPORTING
      ev_error    = DATA(lv_erro_cpi)
      ev_response = DATA(ls_retorno)
  ).

  IF lv_erro_cpi IS NOT INITIAL.
    gv_erro = lv_erro_cpi.
    MESSAGE gv_erro TYPE 'E'.
    RETURN.
  ENDIF.

  "// Converte o JSON na Estrutura ABAP
  /ui2/cl_json=>deserialize( EXPORTING json         = ls_retorno
                                       pretty_name  = /ui2/cl_json=>pretty_mode-none
                              CHANGING data         = gs_quest_response ).

  PERFORM f_mostrar_questoes.

ENDFORM. "f_gera_questionario

FORM f_mostrar_questoes.

  LOOP AT gs_quest_response-questoes INTO DATA(ls_questoes).
    DATA(lv_questao) = |{ sy-tabix } - { ls_questoes-questao } |.

    IF ls_questoes-tipo EQ 'objetiva'.
      IF strlen( lv_questao ) > 79.
        gv_qest1 = lv_questao(79).
        gv_qestc = lv_questao+79(*).
      ELSE.
        gv_qest1 = lv_questao.
        CLEAR gv_qestc.
      ENDIF.

      LOOP AT ls_questoes-opcoes INTO DATA(ls_opcoes).
        CASE sy-tabix.
          WHEN 1.
            gv_resp1 = ls_questoes-opcoes[ sy-tabix ].
          WHEN 2.
            gv_resp2 = ls_questoes-opcoes[ sy-tabix ].
          WHEN 3.
            gv_resp3 = ls_questoes-opcoes[ sy-tabix ].
          WHEN 4.
            gv_resp4 = ls_questoes-opcoes[ sy-tabix ].
        ENDCASE.
      ENDLOOP.
      CALL SELECTION-SCREEN 3000.

    ELSE.
      IF strlen( lv_questao ) > 79.
        gv_qest2 = lv_questao(79).
        gv_qesta = lv_questao+79(*).
      ELSE.
        gv_qest2 = lv_questao.
        CLEAR gv_qesta.
      ENDIF.
      gv_qest2 = |{ sy-tabix } - { ls_questoes-questao } |.

      gv_respv = 'A. Verdadeiro'.
      gv_respf = 'B. Falso'.
      CALL SELECTION-SCREEN 4000.

    ENDIF.
    PERFORM f_corrige_questao USING ls_questoes-id.
  ENDLOOP.

ENDFORM. "f_mostrar_questoes

*&---------------------------------------------------------------------*
*&      --> LS_QUESTOES_ID - número da questão
*&---------------------------------------------------------------------*
FORM f_corrige_questao USING lv_questao.
  DATA lv_resposta_questao TYPE bool.

  READ TABLE gs_quest_response-questoes WITH KEY id = lv_questao
                                                 tipo = 'objetiva' ASSIGNING FIELD-SYMBOL(<fs_questao_corrige>).
  IF sy-subrc IS NOT INITIAL.
    READ TABLE gs_quest_response-questoes WITH KEY id = lv_questao
                                                 tipo = 'verdadeiro_falso' ASSIGNING <fs_questao_corrige>.
  ENDIF.

  CASE <fs_questao_corrige>-tipo.
    WHEN 'objetiva'.
      <fs_questao_corrige>-resposta_usuario = COND #( WHEN p_op1 EQ 'X' THEN 'A'
                                                      WHEN p_op2 EQ 'X' THEN 'B'
                                                      WHEN p_op3 EQ 'X' THEN 'C'
                                                      WHEN p_op4 EQ 'X' THEN 'D' ).
    WHEN 'verdadeiro_falso'.
      <fs_questao_corrige>-resposta_usuario = COND #( WHEN p_opv EQ 'X' THEN 'V'
                                                      WHEN p_opf EQ 'X' THEN 'F' ).
  ENDCASE.

  IF <fs_questao_corrige>-resposta_usuario EQ <fs_questao_corrige>-resposta_correta.
    <fs_questao_corrige>-acerto_erro = 'X'.
    gv_nota += 1.
    MESSAGE 'Acertou!' TYPE 'S'.
  ELSE.
    lv_resposta_questao = abap_false.
    MESSAGE 'Errou!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM. "f_corrige_questao

*&---------------------------------------------------------------------*
*& Form f_imprime_resultado
*&---------------------------------------------------------------------*
*& Função para mostrar na tela o resultado do questionário
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM f_imprime_resultado.
  DATA: lv_porcentagem TYPE f VALUE '0.7',
        lv_media       TYPE f,
        lv_texto       TYPE string.

  lv_media = p_total * lv_porcentagem.

  WRITE:/ |===========================================================================================================================================================================================|,/
          |                                                                                       CORREÇÃO                                                                                            |,/
          |===========================================================================================================================================================================================|,/.

  WRITE:/ |MÉDIA NECESSÁRIA: { lv_media }|  COLOR COL_HEADING,
        / |NOTA FINAL: { gv_nota }|         COLOR COL_TOTAL,
        / |VALOR: { p_total }|              COLOR COL_GROUP.

  IF gv_nota LT lv_media.
    lv_texto = 'Precisa melhorar =('.
    FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
  ELSE.
    lv_texto = 'Parabéns! :)'.
    FORMAT COLOR COL_POSITIVE INTENSIFIED ON.
  ENDIF.

  WRITE:/ |RESULTADO:', { lv_texto }|.
  FORMAT COLOR OFF.

  WRITE:/ '--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'.

  LOOP AT gs_quest_response-questoes INTO DATA(ls_questoes).
    " Exibir status da questão (Acerto/Erro)
    IF ls_questoes-acerto_erro EQ 'X'.
      FORMAT COLOR COL_POSITIVE INTENSIFIED ON.
      WRITE:/ '>> Você Acertou! :)'.
    ELSE.
      FORMAT COLOR COL_NEGATIVE INTENSIFIED ON.
      WRITE:/ '>> Você Errou! :('.
    ENDIF.
    FORMAT COLOR OFF.

    WRITE:/ |{ sy-tabix } - { ls_questoes-questao }| COLOR COL_HEADING.

    " Exibir as opções da questão
    LOOP AT ls_questoes-opcoes INTO DATA(ls_questoes_opcoes).
      WRITE:/ ' -', ls_questoes_opcoes COLOR COL_NORMAL.
    ENDLOOP.

    " Exibir respostas e explicação
    WRITE:/ 'Sua Resposta    :', ls_questoes-resposta_usuario COLOR COL_NEGATIVE,
          / 'Resposta Correta:', ls_questoes-resposta_correta COLOR COL_POSITIVE,
          / 'Explicação      :', ls_questoes-explicacao.
    WRITE:/ '--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'.
  ENDLOOP.
ENDFORM. "f_imprime_resultado