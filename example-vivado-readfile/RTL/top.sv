
//--------------------------------------------------------------------------------------------------------
// Module  : top
// Type    : synthesizable, FPGA's top, IP's example design
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: an example of sd_file_reader, read a file from SDcard and send file content to UART
//           this example runs on Digilent Nexys4-DDR board (Xilinx Artix-7),
//           see http://www.digilent.com.cn/products/product-nexys-4-ddr-artix-7-fpga-trainer-board.html
//--------------------------------------------------------------------------------------------------------

module top (
    // clock = 100MHz
    input  wire         clk100mhz,
    // rstn active-low, You can re-read SDcard by pushing the reset button.
    input  wire         resetn,
    // when sdcard_pwr_n = 0, SDcard power on
    output wire         sdcard_pwr_n,
    // signals connect to SD bus
    output wire         sdclk,
    inout               sdcmd,
    input  wire         sddat0,
    output wire         sddat1, sddat2, sddat3,
    // 16 bit led to show the status of SDcard
    output wire [15:0]  led,
    // UART tx signal, connected to host-PC's UART-RXD, baud=115200
    output wire         uart_tx
);

assign led[15:9] = '0;

assign sdcard_pwr_n = 1'b0;

assign {sddat1, sddat2, sddat3} = 3'b111;  // Must set sddat1~3 to 1 to avoid SD card from entering SPI mode


wire       outen;     // when outen=1, a byte of file content is read out from outbyte
wire [7:0] outbyte;   // a byte of file content


//----------------------------------------------------------------------------------------------------
// sd_file_reader
//----------------------------------------------------------------------------------------------------
sd_file_reader #(
    .FILE_NAME        ( "example.txt"  ),  // file name to read
    .CLK_DIV          ( 2              ),  // because clk=100MHz, CLK_DIV is set to 2
    .SIMULATE         ( 0              )
) sd_file_reader_i (
    .rstn             ( resetn         ),
    .clk              ( clk100mhz      ),
    .sdclk            ( sdclk          ),
    .sdcmd            ( sdcmd          ),
    .sddat0           ( sddat0         ),
    .card_stat        ( led[3:0]       ),  // show the sdcard initialize status
    .card_type        ( led[5:4]       ),  // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
    .filesystem_type  ( led[7:6]       ),  // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
    .file_found       ( led[  8]       ),  // 0=file not found, 1=file found
    .outen            ( outen          ),
    .outbyte          ( outbyte        )
);


//----------------------------------------------------------------------------------------------------
// send file content to UART
//----------------------------------------------------------------------------------------------------
uart_tx #(
    .CLK_DIV          ( 868            ),   // 100MHz/868 = 115200
    .PARITY           ( "NONE"         ),   // no parity bit
    .ASIZE            ( 14             ),   //
    .DWIDTH           ( 1              ),   // tx_data is 8 bit (1 Byte)
    .ENDIAN           ( "LITTLE"       ),   //
    .MODE             ( "RAW"          ),   //
    .END_OF_DATA      ( ""             ),   //
    .END_OF_PACK      ( ""             )    //
) uart_tx_i (
    .rstn             ( resetn         ),
    .clk              ( clk100mhz      ),
    .tx_data          ( outbyte        ),
    .tx_last          ( 1'b0           ),
    .tx_en            ( outen          ),
    .tx_rdy           (                ),
    .o_uart_tx        ( uart_tx        )
);

endmodule
