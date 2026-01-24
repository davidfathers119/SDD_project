--RS232TX
Library IEEE;
Use IEEE.std_logic_1164.all;
Use IEEE.std_logic_unsigned.all;
-- ----------------------------------------------------
Entity RS232_T1 is
	Port(Clk,Reset:in std_logic;
		 DL:in std_logic_vector(1 downto 0);	 --00:5,01:6,10:7,11:8 Bit
		 ParityN:in std_logic_vector(2 downto 0);--0xx:None,100:Even,101:Odd,110:Space,111:Mark
		 StopN:in std_logic_vector(1 downto 0);	 --0x:1Bit,10:2Bit,11:1.5Bit
		 F_Set:in std_logic_vector(2 downto 0);
		 Status_s:out std_logic_vector(1 downto 0);
		 TX_W:in std_logic;
		 TXData:in std_logic_vector(7 downto 0);
		 TX:out std_logic);
End RS232_T1;
-- -----------------------------------------------------
Architecture RS232_T1_Arch of RS232_T1 is
Signal StopNn:std_logic_vector(2 downto 0);
Signal Tx_B_Empty,Tx_B_Clr,TxO_W:std_logic;
-------------
Signal Tx_f,T_Half_f,TX_P_NEOSM:std_logic;
Signal TXDs_Bf,TXD2_Bf:std_logic_vector(7 downto 0);
Signal Tsend_DLN,DLN:std_logic_vector(3 downto 0);
Signal Tx_s:std_logic_vector(2 downto 0);
Signal TX_BaudRate:integer range 0 to 20832;
Signal BaudRate1234:std_logic_vector(1 downto 0);
-- --------------------------
Begin
Status_s<=Tx_B_Empty & TxO_W;
-----------------------------
TxWP:Process(TX_W,Reset)
Begin
If reset='0' or Tx_B_Clr='1' Then
	Tx_B_Empty<='0';
	TxO_W<='0';
Elsif Tx_W'event and Tx_W='1' Then
	TXD2_Bf<=TXData;
	Tx_B_Empty<='1';		--Tx_B_Empty='1'表示已有資料寫入(尚未傳出)
	TxO_W<=Tx_B_Empty;		--TxO_W='1'表示資料未傳出又寫入資料(覆寫)
End If;
End Process TxWP;
---------------------------------------------------------------
TxP:Process(Tx_f,Reset)
Begin
If Reset='0' Then
	Tx_s<="000";
	TX<='1';
	Tx_B_Clr<='0';
Elsif Tx_f'event and Tx_f='1' Then
	If Tx_s=0 and Tx_B_Empty='1' Then--start bit
		TXDs_Bf<=TXD2_Bf;
		TX<='0';					--start bit
		Tsend_DLN<="0000";
		TX_P_NEOSM<=ParityN(0);		--Even,Odd,Space or Mark
		Tx_B_Clr<='1';
		T_Half_f<='0';
		Tx_s<="001";
	Elsif Tx_s/=0 Then
		Tx_B_Clr<='0';
		T_Half_f<=Not T_Half_f;
		Case Tx_s is
			When "001" =>
				If T_Half_f='1' Then
					if Tsend_DLN=DLN Then
						If ParityN(2)='0' Then 	--None Parity Bit
							Tx_s<=StopNn;
							TX<='1';			--Stop Bit
						Else
							TX<=TX_P_NEOSM;		--Parity Bit
							Tx_s<="010";
						End If;
					Else
						If ParityN(1)='0' Then
							TX_P_NEOSM<=TX_P_NEOSM Xor TXDs_Bf(0);--Even or Odd
						End If;
						TX<=TXDs_Bf(0);			--Send Data:Bit 0..7
						TXDs_Bf<=TXDs_Bf(0) & TXDs_Bf(7 Downto 1);
						Tsend_DLN<=Tsend_DLN+1;
					End If;
				End If;
			When "011" =>
				Tx_s<=StopNn;
				TX<='1';	--Stop Bit
			When oThers=>
				Tx_s<=Tx_s+1;
		End Case;
	End If;
End If;
End Process TxP;
--------------------------
TxBaudP:process(Clk,Reset)
VARIABLE f_Div:integer range 0 to 20832;
Begin
	If Reset='0' Then
		f_Div:=0;Tx_f<='0';BaudRate1234<="00";
	Elsif clk'event and clk='1' Then
		If f_Div=TX_BaudRate Then
			f_Div:=0;
			Tx_f<=Not Tx_f;
			BaudRate1234<=BaudRate1234+1;
		Else
			f_Div:=f_Div+1;
		End If;
	End If;
End Process TxBaudP;
------------------------------------------
With (F_Set & BaudRate1234) Select
  TX_BaudRate<=	--Baud Rate Set 依Clk=25MHz設定
		20832 When "00000",--300:25000000/((20832+1)*4)=300.0048001
		20832 When "00001",--300
		20832 When "00010",--300
		20832 When "00011",--300
        10416 When "00100",--600
        10416 When "00101",--600
        10416 When "00110",--600
        10416 When "00111",--600
        5207  When "01000",--1200
        5207  When "01001",--1200
        5207  When "01010",--1200
        5207  When "01011",--1200
        2603  When "01100",--2400
        2603  When "01101",--2400
        2603  When "01110",--2400
        2603  When "01111",--2400
        1301  When "10000",--4800
        1301  When "10001",--4800
        1301  When "10010",--4800
        1301  When "10011",--4800
        650   When "10100",--9600
        650   When "10101",--9600
        650   When "10110",--9600
        650   When "10111",--9600
        324   When "11000",--19200
        325   When "11001",--19200校正頻率
        324   When "11010",--19200
        325   When "11011",--19200校正頻率
        162   When "11100",--38400
        162   When "11101",--38400
        161   When "11110",--38400校正頻率
        162   When "11111",--38400
        0 	  When oThers;
----------------------------------
With DL Select				--Data Length 
  DLN<= "0101" When "00",   --5bit 
        "0110" When "01",	--6bit
        "0111" When "10",	--7bit
        "1000" When "11",	--8bit
        "0000" When oThers;
----------------------------------        
With StopN Select			--Stop Bit
  StopNn<="101" When "10",	--2Bit
          "110" When "11",	--1.5Bit
          "111" When oThers;--1Bit
---------------------------------------------------------------
End RS232_T1_Arch;
