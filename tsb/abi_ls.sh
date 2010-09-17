#!/bin/sh

case $1 in
PING)
    #������� �������� ��������� stat
    echo "PONG"
    ;;
REQ_INF)
    #������� ������� ���������� �� ��������
    #$1 - �� ������������ (tsb_t_usr.ytrn.a_ident, char[100+1])
    #$2 - ������ ������������ (char[32+1])
    #XXX: ��� �������� ����� ���������� ������ (��� � ����� 
    #     ���������� ���������) �� ����� ��������� � ps.
    #XXX: ������ ����� ���������� ��� ������� ����� (��������!)

    #id ������������
    echo "USER" 
    #�������� ������ � ������������  (GROUP ��_������ ���_������)
    echo "ADDGROUP 0 ������ 0" 
    #�����������-���������� �������
    echo "NAMEORG ���������� �������" 
    #������������ �������
    echo "NAMESCHET ������1"
    #������� ���� �����������
    echo "LSCHET 000111-0000-0000"
    #��� �����
    echo "NUMSCHET ��������"
    #���
    echo "BIK 123456789" 
    #�������� ���� ���������� �������"
    echo "SCHET 01234567890123456789"
    #��� ���������
    echo "INN 123456789012"
    #����
    echo "BANKNAME ��� ����"
    #�������
    echo "CORSCHET 01234567890123456789"
    #��������
    echo "PERCENT 0"
    #����������� ���� ��������
    echo "AMOUNTMIN 0.0"
    #������������ ����� ��������
    echo "AMOUNTMAX 0.0"
    #������� ������� ��� ��������
    echo "DOGOVOR 0"
    #��� ������� (0 - �������������, 1 - ���������, � ��)
    echo "TYPEBILL 0"
    #��� �����������
    echo "FIO ������ ����� ��������"
    #��� �����
    echo "STREET ����������������"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    #������
    echo "PERIOD 01.1980"
    #���������� ���� �������
    echo "AMOUNT 500"
    #������������ ��������� �����
    echo "AMOUNTOVER 500"
    #�������� �������������� BLL � ������������ � ������
    echo "ADDBILL"
    #��������� ���������
    echo "ZPAR_SHORTNAME ����0"
    echo "ZPAR_FULLNAME ��������� 0"
    echo "ZPAR_POS 0"
    echo "ZPAR_NEED 1"
    echo "ZPAR_TYPE C"
    echo "ZPAR_RELPOS 0"
    echo "ZPAR_LENMIN 0"
    echo "ZPAR_LENMAX 10"
    echo "ZPAR_ALGO 0"
    echo "ZPAR_VALUE ��������0"
    #�������� �������� � bll
    echo "ADD_ZPAR"
    echo "ZPAR_SHORTNAME ����1"
    echo "ZPAR_FULLNAME ��������� 1"
    echo "ZPAR_POS 1"
    echo "ZPAR_NEED 1"
    echo "ZPAR_TYPE C"
    echo "ZPAR_RELPOS 0"
    echo "ZPAR_LENMIN 0"
    echo "ZPAR_LENMAX 10"
    echo "ZPAR_ALGO 0"
    echo "ZPAR_VALUE ��������1"
    echo "ADD_ZPAR"
      
    #�������� Bll
    echo "LSCHET 000111-0000-0002"
    echo "NAMEORG ��������� ������� 2"
    echo "NAMESCHET ����� ����� 2" 
    echo "LSCHET 000111-0000-0002"
    echo "NUMSCHET ����������2"
    echo "BIK 123456789" 
    echo "SCHET 01234567890123456789"
    echo "INN 123456789012"
    echo "BANKNAME ��� ����"
    echo "CORSCHET 01234567890123456789"
    echo "PERCENT 0"
    echo "AMOUNTMIN 0.0"
    echo "AMOUNTMAX 0.0"
    echo "DOGOVOR 0"
    echo "TYPEBILL 0"
    echo "FIO ������ ����� ��������"
    echo "STREET ����������������"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    echo "PERIOD 01.1980"
    echo "AMOUNT 500"
    echo "AMOUNTOVER 500"
    echo "ADDBILL"

    #��������� ������ 1
    echo "ADDGROUP 1 ������ 1"
    #��������� Bll
    echo "NAMEORG nameorg0(grp1)"
    echo "NAMESCHET nameschet0(grp1)"
    echo "LSCHET 000111-0000-0001"
    echo "NUMSCHET numschet0(grp1)"
    echo "BIK 123456789" 
    echo "SCHET 01234567890123456789"
    echo "INN 123456789012"
    echo "BANKNAME ��� ����"
    echo "CORSCHET 01234567890123456789"
    echo "PERCENT 0"
    echo "AMOUNTMIN 0.0"
    echo "AMOUNTMAX 0.0"
    echo "DOGOVOR 0"
    echo "TYPEBILL 0"
    echo "FIO ������ ����� ��������"
    echo "STREET ����������������"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    echo "PERIOD 01.1980"
    echo "AMOUNT 500"
    echo "AMOUNTOVER 500"
    #��������� ���
    echo "ADDBILL"
    ;;
    
REQ_PAY)
    #������� ������ req_pay
    # $1 - ytrn.a_ident
    # $2 - ytrna_fillial_num
    # $3 - ytrn.a_termnum
    # $4 - ydoc.a_docnum
    # $5 - ydoc.a_payment
    # $6 - ydoc.a_tran
    # $7 - ytrn.a_date
    # $8 - ytrn.a_ltime
    #
    # �������� ������
    # echo "OK"
    # ������ (ERROR �����_������)
    echo "ERROR �������� ����� ��������"
    # echo "ERROR ������������ �����"
    ;; 
*)
    echo "ERROR: unknown cmd $1"
    ;;
esac
    
