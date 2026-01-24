--RS232RX
Library IEEE;
	Use IEEE.std_logic_1164.all;
	Use IEEE.std_logic_unsigned.all;
-- ----------------------------------------------------
Entity RS232_R2 is
	Port(Clk,Reset:in std_logic;
		 DL:in std_logic_vector(1 downto 0);	 --00:5,01:6,10:7,11:8 Bit
		 ParityN:in std_logic_vector(2 downto 0);--0xx:None,100:Even,101:Odd,110:Space,111:Mark
		 StopN:in std_logic_vector(1 downto 0);	 --0x:1Bit,10:2Bit,11:1.5Bit
		 F_Set:in std_logic_vector(2 downto 0);
		 Status_s:out std_logic_vector(2 downto 0);
		 Rx_R:in std_logic;
		 RD:in std_logic;
		 RxDs:out std_logic_vector(7 downto 0));
End RS232_R2;
-- -----------------------------------------------------
Architecture RS232_R2_Arch of RS232_R2 is
Signal StopNn:std_logic_vector(2 downto 0);
Signal Rx_B_Empty,Rx_P_Error,Rx_OW,Rx_R2:std_logic;
-------------
Signal RDf,Rx_f,Rx_PEOSM,R_Half_f:std_logic;
Signal RxD,RxDB:std_logic_vector(7 downto 0);
Signal Rsend_RDLNs,RDLN:std_logic_vector(3 downto 0);
Signal Rc:std_logic_vector(2 downto 0);
Signal Rx_s,Rff,BaudRate1234:std_logic_vector(1 downto 0);
Signal RX_BaudRate:integer range 0 to 20832;
-- --------------------------
Begin
Status_s<=Rx_B_Empty & Rx_P_Error & Rx_OW;
RDf<=Clk When (Rx_s(0) = Rx_s(1)) Else Rx_f;
-------------------------------------------
RxP:Process(RDf,Reset)
Begin
If Reset='0' Then
	Rx_OW<='0';
	Rx_B_Empty<='0';
	Rx_P_Error<='0';
	Rx_R2<=Rx_R;
	Rx_s<="00";
	RxDs<=X"00";
Elsif RDf'event and RDf='0' Then
	If Rx_R2/=Rx_R and Rsend_RDLNs/=RDLN Then
		If Rx_R='1' Then
			Rx_OW<='0';
			Rx_B_Empty<='0';
			Rx_P_Error<='0';
		End If;
		Rx_R2<=Rx_R;
	End If;
	If Rx_s=0 Then
		If RD='0' Then	--Start Bit
			Rx_s<="01";
			R_Half_f<='1';
			Rx_PEOSM<=ParityN(0);
		End If;
		Rsend_RDLNs<="0000";
	Elsif Rx_s="11" Then--Stop Bit
		Rx_s<=Not (RD & RD);
	Else
		R_Half_f<=Not R_Half_f;
		If R_Half_f='1' Then
			If Rsend_RDLNs=RDLN Then
				RxDs<=RxDB;
				Rx_B_Empty<='1';			--Rx Buffer Full
				Rx_OW<=Rx_B_Empty; 			--Rx Buffer Over Write
				If ParityN(2)='1' Then		--Now is Parity Bit
					If RD/=Rx_PEOSM Then
						Rx_P_Error<='1';	--Parity Error
					End If;					
					Rx_s<="11";
				Else						--Now is Stop Bit
					Rx_s<="00";
				End If;
			Else							--Now is Start or Data Bit
				RxD<=RD & RxD(7 Downto 1);
				Rx_PEOSM<=Rx_PEOSM Xor RD;
				Rsend_RDLNs<=Rsend_RDLNs+1;	--含Start Bit
			End If;
		End If;
	End If;
End If;
End Process RxP;
------------------------------------------
RxBaudP:process(Clk,Rx_s)
VARIABLE F_Div:integer range 0 to 20832;
Begin
	If Rx_s(0)=Rx_s(1) Then
		F_Div:=0;Rx_f<='1';BaudRate1234<="00";
	Elsif Clk'event and Clk='1' Then
		If F_Div=RX_BaudRate Then
			F_Div:=0;
			Rx_f<=Not Rx_f;
			BaudRate1234<=BaudRate1234+1;
		Else
			F_Div:=F_Div+1;
		End If;
	End If;
End Process RxBaudP;
------------------------------------------
With (F_Set & BaudRate1234) Select
  RX_BaudRate<=	--Baud Rate Set 依Clk=25MHz設定
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
-------------------------------
With DL Select	--Data Length 含Start Bit
  RDLN<="0110" When "00",   --5bit 
        "0111" When "01",	--6bit
        "1000" When "10",	--7bit
        "1001" When "11",	--8bit
        "0000" When oThers;
-------------------------------
With DL Select	--Data Length 
  RxDB<="000" & RxD(7 Downto 3) When "00",	--5bit 
        "00" & RxD(7 Downto 2) When "01",	--6bit
        "0" & RxD(7 Downto 1) When "10",	--7bit
        RxD 				 When "11",		--8bit
        "11111111" 			When oThers;
-------------------------------
With StopN Select
  StopNn<="101" When "10",--2bit
          "110" When "11",--1.5bit
          "111" When oThers; --1bit
----------------------------------------------------
End RS232_R2_Arch;
