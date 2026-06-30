with STM32G431xx;
with STM32G431xx.RCC;
with MT;

package body STM32G431_SPI is

   use STM32G431xx.SPI;
   use type STM32G431xx.Bit;
   use type Spi_Types.Clock_Polarity;
   use type Spi_Types.Clock_Phase;
   use type Spi_Types.Bit_Order_Kind;
   use type Spi_Types.Data_Size_Kind;

   DR_Wait_Timeout : constant Natural := 1_000_000;

   function To_BR (Periph_Clock : Natural;
                   Target       : Spi_Types.Clock_Frequency)
                   return STM32G431xx.UInt3
   is
      Target_Hz : constant Natural :=
        (case Target is
            when Spi_Types.F_100K =>       100_000,
            when Spi_Types.F_400K =>       400_000,
            when Spi_Types.F_1M   =>     1_000_000,
            when Spi_Types.F_2M   =>     2_000_000,
            when Spi_Types.F_4M   =>     4_000_000,
            when Spi_Types.F_8M   =>     8_000_000,
            when Spi_Types.F_10M  =>    10_000_000,
            when Spi_Types.F_20M  =>    20_000_000,
            when Spi_Types.F_40M  =>    40_000_000);
      Divisor : Natural := 2;
   begin
      for BR in STM32G431xx.UInt3 loop
         if Periph_Clock / Divisor <= Target_Hz then
            return BR;
         end if;
         Divisor := Divisor * 2;
      end loop;
      raise Spi_Types.SPI_Unsupported;
   end To_BR;

   function Is_Enabled return Boolean is
   begin
      return Periph.CR1.SPE = 1;
   end Is_Enabled;

   procedure Init (Cfg : Spi_Types.Spi_Config) is
      Pclk : constant Natural := Get_Clock;
   begin
      RCC_Enable;

      Periph.CR1.SPE := 0;

      Periph.CR1.CPOL :=
        (if Cfg.Mode.Polarity = Spi_Types.High then 1 else 0);
      Periph.CR1.CPHA :=
        (if Cfg.Mode.Phase = Spi_Types.Edge_2 then 1 else 0);

      Periph.CR1.BR := To_BR (Pclk, Cfg.Frequency);

      Periph.CR1.LSBFIRST :=
        (if Cfg.Bit_Order = Spi_Types.LSB_First then 1 else 0);

      Periph.CR2.DS :=
        (case Cfg.Data_Size is
            when Spi_Types.Data_8  => STM32G431xx.UInt4 (7),
            when Spi_Types.Data_16 => STM32G431xx.UInt4 (15));

      Periph.CR2.FRXTH :=
        (if Cfg.Data_Size = Spi_Types.Data_8 then 1 else 0);

      Periph.CR1.MSTR := 1;
      Periph.CR1.SSM  := 1;
      Periph.CR1.SSI  := 1;
   end Init;

   procedure Enable is
   begin
      Periph.CR1.SPE := 1;
   end Enable;

   procedure Disable is
   begin
      while Periph.SR.BSY = 1 loop
         null;
      end loop;
      Periph.CR1.SPE := 0;
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

      while Periph.SR.TXE = 0 loop
         Wait_Count := Wait_Count + 1;
         if Wait_Count >= DR_Wait_Timeout then
            Accepted := False;
            return;
         end if;
      end loop;

      declare
         DR8 : MT.UInt8
           with Address => Periph.DR'Address, Volatile, Import;
      begin
         DR8 := MT.UInt8 (B);
      end;
      Accepted := True;
   end Tx_Push;

   procedure Rx_Pop
     (B         : out Storage_Element;
      Available : out Boolean)
   is
   begin
      B := 0;

      if not Is_Enabled then
         Available := False;
         return;
      end if;

      if Periph.SR.RXNE = 1 then
         declare
            DR8 : MT.UInt8
              with Address => Periph.DR'Address, Volatile, Import;
         begin
            B := Storage_Element (DR8);
         end;
         Available := True;
      else
         Available := False;
      end if;
   end Rx_Pop;

   procedure Transfer
     (TX : Storage_Element;
      RX : out Storage_Element)
   is
      Wait_Count : Natural := 0;
   begin
      RX := 0;

      if not Is_Enabled then
         raise Spi_Types.SPI_Error with "Transfer: peripheral not enabled";
      end if;

      while Periph.SR.TXE = 0 loop
         Wait_Count := Wait_Count + 1;
         if Wait_Count >= DR_Wait_Timeout then
            raise Spi_Types.SPI_Error with "Transfer: TXE timeout";
         end if;
      end loop;

      declare
         DR8 : MT.UInt8
           with Address => Periph.DR'Address, Volatile, Import;
      begin
         DR8 := MT.UInt8 (TX);
      end;

      Wait_Count := 0;
      while Periph.SR.RXNE = 0 loop
         Wait_Count := Wait_Count + 1;
         if Wait_Count >= DR_Wait_Timeout then
            raise Spi_Types.SPI_Error with "Transfer: RXNE timeout";
         end if;
      end loop;

      declare
         DR8 : MT.UInt8
           with Address => Periph.DR'Address, Volatile, Import;
      begin
         RX := Storage_Element (DR8);
      end;
   end Transfer;

end STM32G431_SPI;