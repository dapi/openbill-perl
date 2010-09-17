#������ ��� �������������� ������ ������ � �������� � locals.txt ������� reporter�

BEGIN{
	group_no=1;
}

NR <= 4 { next }

NF == 7{
	ip=$1;
	tariff_id=$5
	is_unlim=$6
	speed=$7
	if ( is_unlim )
		tariff_name = "unlim_" speed;
	else
		tariff_name = "other";

	if ( tarifes[tariff_name] == 0 ) {
		printf "%i %s\n", group_no, tariff_name;
		tarifes[tariff_name] = group_no++;
	}

	printf("%i %s\n", tarifes[tariff_name], ip);
}

END {
    # ������ ������� ��� � ��������
    # ������������ ����, �� ������� �����    
    printf "1 77.240.152.0/24\n"
}
