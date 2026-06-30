with STM32G431xx;
with STM32G431xx.RCC;
with STM32G431xx.USART;

package body STM32G431_USART is

   use STM32G431xx.USART;
   use type Usart_Types.Parity_Kind;
   use type Usart_Types.Stop_Bits_Kind;
   use type Usart_Types.Flow_Control_Kind;
   use type STM32G431xx.Bit;

   TXE_Wait_Timeout      : constant Natural := 1_000_000;
   Clock_Startup_Timeout : constant Natural := 1_000_000;

   procedure Compute_BRR
     (Pclk     : Natural;
      Baud     : Natural;
      Mantissa : out STM32G431xx.UInt12;
      Fraction : out STM32G431xx.UInt4)
   is
      Divisor : constant Natural := 16 * Baud;
      Mant    : Natural          := Pclk / Divisor;
      Remm    : constant Natural := Pclk mod Divisor;
      Frac    : Natural;
   begin
      Frac := ((Remm * 16) + (Divisor / 2)) / Divisor;

      if Frac = 16 then
         Mant := Mant + 1;
         Frac := 0;
      end if;

      Mantissa :=
        (if Mant > Natural (STM32G431xx.UInt12'Last)
         then STM32G431xx.UInt12'Last
         else STM32G431xx.UInt12 (Mant));

      Fraction :=
        (if Frac > Natural (STM32G431xx.UInt4'Last)
         then STM32G431xx.UInt4'Last
         else STM32G431xx.UInt4 (Frac));
   end Compute_BRR;

   function Baud_To_Int (B : Usart_Types.Baud_Rate) return Natural is
   begin
      case B is
         when Usart_Types.B1200   => return 1_200;
         when Usart_Types.B2400   => return 2_400;
         when Usart_Types.B4800   => return 4_800;
         when Usart_Types.B9600   => return 9_600;
         when Usart_Types.B19200  => return 19_200;
         when Usart_Types.B38400  => return 38_400;
         when Usart_Types.B57600  => return 57_600;
         when Usart_Types.B115200 => return 115_200;
         when Usart_Types.B230400 => return 230_400;
         when Usart_Types.B460800 => return 460_800;
         when Usart_Types.B921600 => return 921_600;
         when Usart_Types.B1M     => return 1_000_000;
         when Usart_Types.B2M     => return 2_000_000;
      end case;
   end Baud_To_Int;

   function Is_Enabled return Boolean is
   begin
      return Periph.CR1.UE = 1;
   end Is_Enabled;

   function Is_Initialized return Boolean is
      use type STM32G431xx.UInt12;
   begin
      return Periph.BRR.DIV_Mantissa /= 0;
   end Is_Initialized;

   procedure Init (Cfg : Usart_Types.Usart_Config)
   is
      Pclk  : Natural;
      Baud  : constant Natural := Baud_To_Int (Cfg.Baud);
      Mant  : STM32G431xx.UInt12;
      Frac  : STM32G431xx.UInt4;
      Loops : Natural := Clock_Startup_Timeout;
   begin
      STM32G431xx.RCC.RCC_Periph.CR.HSION    := 1;
      STM32G431xx.RCC.RCC_Periph.CR.HSIKERON := 1;

      while STM32G431xx.RCC.RCC_Periph.CR.HSIRDY = 0
        and then Loops > 0
      loop
         Loops := Loops - 1;
      end loop;

      if STM32G431xx.RCC.RCC_Periph.CR.HSIRDY = 0 then
         raise Usart_Types.USART_Error with "Init: HSI16 clock not ready";
      end if;

      --  Enable peripheral bus clock via RCC formal
      RCC_Enable;

      Pclk := Get_Clock;

      Periph.CR1.UE    := 0;
      Periph.CR1.OVER8 := 0;

      Compute_BRR (Pclk, Baud, Mant, Frac);
      Periph.BRR.DIV_Mantissa := Mant;
      Periph.BRR.DIV_Fraction := Frac;

      Periph.CR1.PCE :=
        (if Cfg.Parity = Usart_Types.None then 0 else 1);
      Periph.CR1.PS :=
        (if Cfg.Parity = Usart_Types.Odd  then 1 else 0);

      case Cfg.Data_Bits is
         when Usart_Types.Data_7 =>
            Periph.CR1.M0 := 0;
            Periph.CR1.M1 := 1;
         when Usart_Types.Data_8 =>
            Periph.CR1.M0 := 0;
            Periph.CR1.M1 := 0;
         when Usart_Types.Data_9 =>
            Periph.CR1.M0 := 1;
            Periph.CR1.M1 := 0;
      end case;

      Periph.CR2.STOP :=
        (if Cfg.Stop_Bits = Usart_Types.Stop_2
         then STM32G431xx.UInt2 (2)
         else STM32G431xx.UInt2 (0));

      Periph.CR3.RTSE :=
        (if Cfg.Flow = Usart_Types.RTS_CTS then 1 else 0);
      Periph.CR3.CTSE :=
        (if Cfg.Flow = Usart_Types.RTS_CTS then 1 else 0);
   end Init;

   procedure Enable is
   begin
      if not Is_Initialized then
         raise Usart_Types.USART_Error with "Enable: peripheral not initialized";
      end if;

      Periph.CR1.TE := 1;
      Periph.CR1.RE := 1;
      Periph.CR1.UE := 1;
   end Enable;

   procedure Disable is
   begin
      Periph.CR1.UE := 0;
   end Disable;

   procedure Reset is
   begin
      RCC_Reset;
   end Reset;

   procedure Tx_Push
     (B        : Storage_Element;
      Accepted : out Boolean)
   is
      Wait_Count : Natural := 0;
   begin
      if not Is_Enabled then
         Accepted := False;
         return;
      end if;

      while Periph.ISR.TXE = 0 loop
         Wait_Count := Wait_Count + 1;
         if Wait_Count >= TXE_Wait_Timeout then
            Accepted := False;
            return;
         end if;
      end loop;

      Periph.TDR.TDR := STM32G431xx.UInt9 (B);
      Accepted := True;
   end Tx_Push;

   procedure Rx_Pop
     (B         : out Storage_Element;
      Available : out Boolean)
   is
   begin
      if not Is_Enabled then
         Available := False;
         return;
      end if;

      if Periph.ISR.RXNE = 1 then
         B         := Storage_Element (Periph.RDR.RDR);
         Available := True;
      else
         Available := False;
      end if;
   end Rx_Pop;

end STM32G431_USART;
