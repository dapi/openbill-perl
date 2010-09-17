#!/bin/sh

case $1 in
PING)
    #Функция проверки состояния stat
    echo "PONG"
    ;;
REQ_INF)
    #Функция запроса информации об абоненте
    #$1 - ид пользователя (tsb_t_usr.ytrn.a_ident, char[100+1])
    #$2 - пароль пользователя (char[32+1])
    #XXX: При передаче через коммандную строку (как и через 
    #     переменные окружения) он будет светиться в ps.
    #XXX: скрипт будет вызываться для каждого юзера (медленно!)

    #id пользователя
    echo "USER" 
    #Добавить группу к пользователю  (GROUP ид_группы имя_группы)
    echo "ADDGROUP 0 группа 0" 
    #Организация-получатель платежа
    echo "NAMEORG Получатель платежа" 
    #Наименование платежа
    echo "NAMESCHET Платеж1"
    #Лицевой счет плательщика
    echo "LSCHET 000111-0000-0000"
    #Код счета
    echo "NUMSCHET Кодсчета"
    #БИК
    echo "BIK 123456789" 
    #Реальный счет получателя платежа"
    echo "SCHET 01234567890123456789"
    #ИНН получаетя
    echo "INN 123456789012"
    #Банк
    echo "BANKNAME НАШ БАНК"
    #Корсчет
    echo "CORSCHET 01234567890123456789"
    #Комиссия
    echo "PERCENT 0"
    #Минимальная сума комиссии
    echo "AMOUNTMIN 0.0"
    #Максимальная сумма комиссии
    echo "AMOUNTMAX 0.0"
    #Признак платежа без комиссии
    echo "DOGOVOR 0"
    #Тип платежа (0 - задолженность, 1 - авансовый, и тд)
    echo "TYPEBILL 0"
    #ФИО плательщика
    echo "FIO Иванов Сидор Петрович"
    #Его адрес
    echo "STREET Коммуникационная"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    #Период
    echo "PERIOD 01.1980"
    #Оплаченная сума платежа
    echo "AMOUNT 500"
    #Выставленная биллингом сумма
    echo "AMOUNTOVER 500"
    #Добавить сформированный BLL к пользователю и группе
    echo "ADDBILL"
    #Добавляем реквизиты
    echo "ZPAR_SHORTNAME Рекв0"
    echo "ZPAR_FULLNAME Реквиизит 0"
    echo "ZPAR_POS 0"
    echo "ZPAR_NEED 1"
    echo "ZPAR_TYPE C"
    echo "ZPAR_RELPOS 0"
    echo "ZPAR_LENMIN 0"
    echo "ZPAR_LENMAX 10"
    echo "ZPAR_ALGO 0"
    echo "ZPAR_VALUE Значение0"
    #Добавить реквизит в bll
    echo "ADD_ZPAR"
    echo "ZPAR_SHORTNAME Рекв1"
    echo "ZPAR_FULLNAME Реквиизит 1"
    echo "ZPAR_POS 1"
    echo "ZPAR_NEED 1"
    echo "ZPAR_TYPE C"
    echo "ZPAR_RELPOS 0"
    echo "ZPAR_LENMIN 0"
    echo "ZPAR_LENMAX 10"
    echo "ZPAR_ALGO 0"
    echo "ZPAR_VALUE Значение1"
    echo "ADD_ZPAR"
      
    #Изменяем Bll
    echo "LSCHET 000111-0000-0002"
    echo "NAMEORG Полчатель платежа 2"
    echo "NAMESCHET Номер счета 2" 
    echo "LSCHET 000111-0000-0002"
    echo "NUMSCHET номерсчета2"
    echo "BIK 123456789" 
    echo "SCHET 01234567890123456789"
    echo "INN 123456789012"
    echo "BANKNAME НАШ БАНК"
    echo "CORSCHET 01234567890123456789"
    echo "PERCENT 0"
    echo "AMOUNTMIN 0.0"
    echo "AMOUNTMAX 0.0"
    echo "DOGOVOR 0"
    echo "TYPEBILL 0"
    echo "FIO Иванов Сидор Петрович"
    echo "STREET Коммуникационная"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    echo "PERIOD 01.1980"
    echo "AMOUNT 500"
    echo "AMOUNTOVER 500"
    echo "ADDBILL"

    #Добавляем группу 1
    echo "ADDGROUP 1 группа 1"
    #Заполняем Bll
    echo "NAMEORG nameorg0(grp1)"
    echo "NAMESCHET nameschet0(grp1)"
    echo "LSCHET 000111-0000-0001"
    echo "NUMSCHET numschet0(grp1)"
    echo "BIK 123456789" 
    echo "SCHET 01234567890123456789"
    echo "INN 123456789012"
    echo "BANKNAME НАШ БАНК"
    echo "CORSCHET 01234567890123456789"
    echo "PERCENT 0"
    echo "AMOUNTMIN 0.0"
    echo "AMOUNTMAX 0.0"
    echo "DOGOVOR 0"
    echo "TYPEBILL 0"
    echo "FIO Иванов Сидор Петрович"
    echo "STREET Коммуникационная"
    echo "HOUSE 13"
    echo "CORPUS 77"
    echo "KVARTIRA 316"
    echo "PERIOD 01.1980"
    echo "AMOUNT 500"
    echo "AMOUNTOVER 500"
    #Добавляем его
    echo "ADDBILL"
    ;;
    
REQ_PAY)
    #Функция оплаты req_pay
    # $1 - ytrn.a_ident
    # $2 - ytrna_fillial_num
    # $3 - ytrn.a_termnum
    # $4 - ydoc.a_docnum
    # $5 - ydoc.a_payment
    # $6 - ydoc.a_tran
    # $7 - ytrn.a_date
    # $8 - ytrn.a_ltime
    #
    # Успешная оплата
    # echo "OK"
    # Ошибка (ERROR текст_ошибки)
    echo "ERROR Неверный номер телефона"
    # echo "ERROR Некорректная сумма"
    ;; 
*)
    echo "ERROR: unknown cmd $1"
    ;;
esac
    
