with Spi_Types;
with STM32G431xx;
with STM32G431xx.SPI;
with System.Storage_Elements; use System.Storage_Elements;

--  STM32G431_SPI models a physical SPI peripheral (SPI1, SPI2, etc.).
--  The instantiation IS the bus. There is no Device type.
--
--  SPI is a one-level abstraction: bus = device.

generic
   Periph         : not null access STM32G431xx.SPI.SPI_Peripheral;
   with function  Get_Clock   return Natural;
   with procedure RCC_Enable;
   with procedure RCC_Reset;
package STM32G431_SPI is

   --  Control-plane hooks

   procedure Init     (Cfg : Spi_Types.Spi_Config);
   procedure Enable;
   procedure Disable;
   procedure Reset;

   --  Data-plane hooks

   procedure Tx_Push  (B        : Storage_Element;
                       Accepted : out Boolean);
   procedure Rx_Pop   (B         : out Storage_Element;
                       Available : out Boolean);
   procedure Transfer (TX : Storage_Element;
                       RX : out Storage_Element);

end STM32G431_SPI;