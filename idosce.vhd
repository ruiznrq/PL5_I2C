LIBRARY IEEE;
USE  IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;

ENTITY idosce IS
PORT
(	
	--Entradas 
	clk:	IN		STD_LOGIC; --Reloj de entrada a 50MHz
	en:	IN		STD_LOGIC; --SW de activación de escrtura (SW[17])
	addr: IN		STD_LOGIC_VECTOR (6 DOWNTO 0); --SW con la direccion de registro
	data: IN    STD_LOGIC_VECTOR (8 DOWNTO 0); --SW con el valor a escribir en el registro
	--Salidas
	clk100:	OUT	STD_LOGIC; --Para pruebas
	clk200:	OUT	STD_LOGIC; --Para pruebas
	SLC:	OUT	STD_LOGIC;
	SDA:	INOUT	STD_LOGIC
);
	
END idosce;

ARCHITECTURE idosce_arch OF idosce IS

	--Estados
	type Estados_posibles is (standby, start, direccion, ack, datos, stop);
	signal estado: 		Estados_posibles := standby;
	--Señales para relojes
	signal clk_100khz: 	STD_LOGIC := '0'; --Reloj de 100kHz, va a SLC
	signal clk_200khz: 	STD_LOGIC := '0'; --Reloj de 200kHz, es interno
	--Dirección del códec
	signal addr_s:			STD_LOGIC_VECTOR(6 DOWNTO 0) := "0011010";
	signal addr_aenviar:	STD_LOGIC_VECTOR(7 DOWNTO 0); --Es addr_s & '0', el '0' es de R/W
	--Señales intermedias
	signal SDA_s:			STD_LOGIC := '1'; --Se convierte a 'Z' cuando es '1'
	signal liberada:		STD_LOGIC := '0';	--Para indicar q se libero la linea de cara a que el esclavo escriba en ella
	signal ack_leido:		STD_LOGIC; --Aqui se almacena el ACK del esclavo
	--Mensaje a enviar
	signal msg:				STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal primer_msg:  	STD_LOGIC := '0'; --Pasamos a uno cuando se envie el primer mensaje.
	signal astop:			STD_LOGIC := '0'; --Pasamos a uno cuando haya que enviar el stop
begin

	--Proceso que genera los relojes de 100KHz y 200kHz----------------------------------
	process (clk)
		variable contador100: integer range 0 to 500 := 0;
		variable contador200: integer range 0 to 250 := 0;
	begin
		IF (clk'event AND clk='1') THEN
			contador100 := contador100 + 1;
			contador200 := contador200 + 1;
			IF (contador100 = 50) THEN 
				clk_100khz <= '1';
			ELSIF (contador100 = 100) THEN	--Para que sean 100kHz, debe contar hasta 500
				clk_100khz <= '0';
				contador100 := 0;
			END IF;
			IF (contador200 = 25) THEN
				clk_200khz <= '1';			
			ELSIF (contador200 = 50) THEN  --Para que sean 200kHz, debe contar hasta 250
				clk_200khz <= '0';
				contador200 := 0;
			END IF;
		END IF;
	END process;
	-------------------------------------------------------------------------------------
	
	--Para depurar:
	clk100<=clk_100khz;
	clk200<=clk_200khz;
	--Asignamos el reloj, de esta forma, a lo largo de todo el programa se trabajan con std_logic de '0' y '1', y se "convierten a la salida"
	SLC <= 'Z' when (estado = standby) else
			'0' when ((estado /= standby) AND (clk_100khz = '0')) else
			'Z' when ((estado /= standby) AND (clk_100khz = '1'));
	
	--Proceso sesible a clk_200khz-------------------------------------------------------
	process (clk_200khz)
		variable cont: integer range 0 to 8 := 0; --Contamos el número de bits mandados
	begin
		IF (EN = '0') THEN	--Si el SW esta bajado, nos quedamos a la espera y liberamos las líneas.
			--INICIALIZACIONES - Evita problemas si se baja el EN en medio de otro estado.
			estado <= standby;
			addr_aenviar <= addr_s(6 DOWNTO 0) & '0'; --Añadimos el cero de R/W
			SDA_s <= '1';
			liberada <= '0';
			ack_leido <= '1';
			msg <= addr(6 DOWNTO 0) & data(8); --Inicializamos con dir de registro y el bit mas significativo a escribir en ese registro
			primer_msg <= '0';
			astop <= '0';
			cont := 0;
		ELSIF (clk_200khz'event AND clk_200khz = '1') THEN --Cada flanco de subida estamos a la mitad del estado bajo/alto de clk_100khz
			IF (estado = standby) THEN	--Si estamos en standby con EN a 1, pasamos a start.
				estado <= start;
			ELSIF (estado = start) AND (clk_100khz = '1') THEN --En estado start, cuando el reloj este en alto, mandamos el flanco bajo de SDA y pasamos a estado direccion
				SDA_s <= '0';
				estado <= direccion;
			ELSIF (estado = direccion) AND (clk_100khz = '0') THEN	--En direccion, cada vez q estemos en la parte baja de SLC, ponemos el bit que será leido en la parte alta
				SDA_s <= addr_aenviar(7); --Mandamos primero MSB
				addr_aenviar <= addr_aenviar(6 DOWNTO 0) & addr_aenviar(7); --Rotamos para q la próxima se envia el siguiente
				cont := cont + 1; --Aumentamos el contador, al ser variable cuando se cambia a 8 entra en el siguiente IF
				IF (cont = 8) THEN --Si ya se envió todo el byte, leemos ack y reiniciamos contador.
					estado <= ack;
					cont := 0;
					liberada <= '0';
				END IF;
			ELSIF (estado = ack) AND (clk_100khz = '0') THEN --Cuando se pone el estado ACK, esperamos a q el reloj este bajo y liberamos la linea.
				SDA_s <= '1';
				liberada <= '1';
			ELSIF (estado = ack) AND (clk_100khz = '1') AND (liberada = '1') THEN --Con la linea liberada y el reloj alto leemos ack
				ack_leido <= SDA;
				IF (astop = '0') THEN --Seguimos enviando hasta q haya que ir a STOP
					estado <= datos;
				ELSIF (astop = '1') THEN --Pasamos a stop
					estado <= stop;
				END IF;
			ELSIF (estado = datos) AND (clk_100khz = '0') AND (ack_leido = '0') THEN --Si el ack leido es correcto, en el estado bajo del reloj escribimos datos
				SDA_s <= msg(7);
				msg <= msg(6 DOWNTO 0) & msg(7); --Rotammos...
				cont := cont + 1;
				IF (cont = 8) AND (primer_msg = '0') THEN --Si ya se envió todo el primer byte, vamos a ack reiniciando contador.
					estado <= ack;
					--Reiniciamos señales intermedias:
					ack_leido <= '1';
					cont := 0;
					liberada <= '0';
					primer_msg <= '1';
					msg <= data(7 DOWNTO 0); --Cambiamos el mensaje para enviar el segundo byte
				ELSIF (cont = 8) AND (primer_msg = '1') THEN --Si ya se envió todo el segundo byte, vamos a ack reiniciando contador.
					estado <= ack;
					--Reiniciamos señales intermedias:
					ack_leido <= '1';
					cont := 0;
					liberada <= '0';
					primer_msg <= '0';
					astop <= '1';
				END IF;
			ELSIF (estado = stop) AND (clk_100khz = '0') AND (ack_leido = '0') THEN --Cuando SLC este bajo, y se se leyó bien el ACK, bajamos SDA para poder enviar el flanco de stop
				SDA_s <= '0';
			ELSIF (estado = stop) AND (clk_100khz = '1') AND (ack_leido = '0') THEN --Mandamos flanco de stop
				SDA_s <= '1';
				ack_leido <= '1'; --Al no ser 0, no se queda entrando en el estado stop.
			END IF;
		END IF;
	END process;
	-------------------------------------------------------------------------------------	
	
	--Adaptamos SDA_s para la salida
	SDA <= 'Z' when (SDA_s = '1') else
			'0' when (SDA_s = '0');

END architecture;
			
			
		 
			
				