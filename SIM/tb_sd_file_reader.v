
//--------------------------------------------------------------------------------------------------------
// Module  : tb_sd_file_reader
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for sd_file_reader
//           connect sd_file_reader (SD-host) to sd_fake (SD-card)
//           sd_file_reader will read sd_fake's content
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_sd_file_reader ();

initial $dumpvars(0, tb_sd_file_reader);


//--------------------------------------------------------------------------------------------------------
// clock and reset
//--------------------------------------------------------------------------------------------------------
reg            rstn = 1'b0;
reg            clk  = 1'b1;
always  #20000 clk  = ~clk;   // 25MHz
initial begin repeat(4) @ (posedge clk); rstn<=1'b1; end


//--------------------------------------------------------------------------------------------------------
// SDIO bus
//--------------------------------------------------------------------------------------------------------
wire        sdclk;
tri         sdcmd;
wire [ 3:0] sddat;


//--------------------------------------------------------------------------------------------------------
// sd_file_reader data out signals
//--------------------------------------------------------------------------------------------------------
wire        outen;
wire [ 7:0] outbyte;
always @ (posedge clk) if(outen) $display("readout byte: %c", outbyte);


//--------------------------------------------------------------------------------------------------------
// sd_file_reader
//--------------------------------------------------------------------------------------------------------
sd_file_reader #(
    .FILE_NAME        ( "example.txt"  ),
    .CLK_DIV          ( 1              ),
    .SIMULATE         ( 1              )
) sd_file_reader_i (
    .rstn             ( rstn           ),
    .clk              ( clk            ),
    .sdclk            ( sdclk          ),
    .sdcmd            ( sdcmd          ),
    .sddat0           ( sddat[0]       ),
    .card_stat        (                ),
    .card_type        (                ),
    .filesystem_type  (                ),
    .file_found       (                ),
    .outen            ( outen          ),
    .outbyte          ( outbyte        )
);


//--------------------------------------------------------------------------------------------------------
// sd_fake's memory interface, connect to a ROM which contains SD-card's data
//--------------------------------------------------------------------------------------------------------
wire        rom_req;
wire [39:0] rom_addr;
reg  [15:0] rom_data;


//--------------------------------------------------------------------------------------------------------
// monitor parsed request command on sdcmd
//--------------------------------------------------------------------------------------------------------
wire        show_sdcmd_en;
wire [ 5:0] show_sdcmd_cmd;
wire [31:0] show_sdcmd_arg;
always @ (posedge sdclk) if(show_sdcmd_en) $display("sdcmd request:  %2d  %08x", show_sdcmd_cmd, show_sdcmd_arg);
initial $display("wait for SD-card power up...");


//--------------------------------------------------------------------------------------------------------
// sd_fake
//--------------------------------------------------------------------------------------------------------
sd_fake sd_fake_i (
    .rstn_async       ( rstn           ),
    .sdclk            ( sdclk          ),
    .sdcmd            ( sdcmd          ),
    .sddat            ( sddat          ),
    .rdreq            ( rom_req        ),
    .rdaddr           ( rom_addr       ),
    .rddata           ( rom_data       ),
    .show_status_bits (                ),
    .show_sdcmd_en    ( show_sdcmd_en  ),
    .show_sdcmd_cmd   ( show_sdcmd_cmd ),
    .show_sdcmd_arg   ( show_sdcmd_arg )
);


//--------------------------------------------------------------------------------------------------------
// A ROM, contains a complete FAT32 partition data mirror
//--------------------------------------------------------------------------------------------------------
always @ (posedge sdclk)
    if (rom_req)
        case (rom_addr)
        40'h00000000df: rom_data <= 16'h8200;
        40'h00000000e0: rom_data <= 16'h0003;
        40'h00000000e1: rom_data <= 16'hd50b;
        40'h00000000e2: rom_data <= 16'hade8;
        40'h00000000e3: rom_data <= 16'h2000;
        40'h00000000e5: rom_data <= 16'hc000;
        40'h00000000e6: rom_data <= 16'h00e6;
        40'h00000000ff: rom_data <= 16'haa55;
        40'h0000200000: rom_data <= 16'h00eb;
        40'h0000200001: rom_data <= 16'h2090;
        40'h0000200002: rom_data <= 16'h2020;
        40'h0000200003: rom_data <= 16'h2020;
        40'h0000200004: rom_data <= 16'h2020;
        40'h0000200005: rom_data <= 16'h0020;
        40'h0000200006: rom_data <= 16'h4002;
        40'h0000200007: rom_data <= 16'h1194;
        40'h0000200008: rom_data <= 16'h0002;
        40'h000020000a: rom_data <= 16'hf800;
        40'h000020000c: rom_data <= 16'h003f;
        40'h000020000d: rom_data <= 16'h00ff;
        40'h000020000e: rom_data <= 16'h2000;
        40'h0000200010: rom_data <= 16'hc000;
        40'h0000200011: rom_data <= 16'h00e6;
        40'h0000200012: rom_data <= 16'h0736;
        40'h0000200016: rom_data <= 16'h0002;
        40'h0000200018: rom_data <= 16'h0001;
        40'h0000200019: rom_data <= 16'h0006;
        40'h0000200020: rom_data <= 16'h0080;
        40'h0000200021: rom_data <= 16'h5929;
        40'h0000200022: rom_data <= 16'he22a;
        40'h0000200023: rom_data <= 16'h4e19;
        40'h0000200024: rom_data <= 16'h204f;
        40'h0000200025: rom_data <= 16'h414e;
        40'h0000200026: rom_data <= 16'h454d;
        40'h0000200027: rom_data <= 16'h2020;
        40'h0000200028: rom_data <= 16'h2020;
        40'h0000200029: rom_data <= 16'h4146;
        40'h000020002a: rom_data <= 16'h3354;
        40'h000020002b: rom_data <= 16'h2032;
        40'h000020002c: rom_data <= 16'h2020;
        40'h00002000ff: rom_data <= 16'haa55;
        40'h0000200100: rom_data <= 16'h5252;
        40'h0000200101: rom_data <= 16'h4161;
        40'h00002001f2: rom_data <= 16'h7272;
        40'h00002001f3: rom_data <= 16'h6141;
        40'h00002001f4: rom_data <= 16'h9a7b;
        40'h00002001f5: rom_data <= 16'h0003;
        40'h00002001f6: rom_data <= 16'h0007;
        40'h00002001ff: rom_data <= 16'haa55;
        40'h00002002ff: rom_data <= 16'haa55;
        40'h0000200600: rom_data <= 16'h00eb;
        40'h0000200601: rom_data <= 16'h2090;
        40'h0000200602: rom_data <= 16'h2020;
        40'h0000200603: rom_data <= 16'h2020;
        40'h0000200604: rom_data <= 16'h2020;
        40'h0000200605: rom_data <= 16'h0020;
        40'h0000200606: rom_data <= 16'h4002;
        40'h0000200607: rom_data <= 16'h1194;
        40'h0000200608: rom_data <= 16'h0002;
        40'h000020060a: rom_data <= 16'hf800;
        40'h000020060c: rom_data <= 16'h003f;
        40'h000020060d: rom_data <= 16'h00ff;
        40'h000020060e: rom_data <= 16'h2000;
        40'h0000200610: rom_data <= 16'hc000;
        40'h0000200611: rom_data <= 16'h00e6;
        40'h0000200612: rom_data <= 16'h0736;
        40'h0000200616: rom_data <= 16'h0002;
        40'h0000200618: rom_data <= 16'h0001;
        40'h0000200619: rom_data <= 16'h0006;
        40'h0000200620: rom_data <= 16'h0080;
        40'h0000200621: rom_data <= 16'h5929;
        40'h0000200622: rom_data <= 16'he22a;
        40'h0000200623: rom_data <= 16'h4e19;
        40'h0000200624: rom_data <= 16'h204f;
        40'h0000200625: rom_data <= 16'h414e;
        40'h0000200626: rom_data <= 16'h454d;
        40'h0000200627: rom_data <= 16'h2020;
        40'h0000200628: rom_data <= 16'h2020;
        40'h0000200629: rom_data <= 16'h4146;
        40'h000020062a: rom_data <= 16'h3354;
        40'h000020062b: rom_data <= 16'h2032;
        40'h000020062c: rom_data <= 16'h2020;
        40'h00002006ff: rom_data <= 16'haa55;
        40'h0000200700: rom_data <= 16'h5252;
        40'h0000200701: rom_data <= 16'h4161;
        40'h00002007f2: rom_data <= 16'h7272;
        40'h00002007f3: rom_data <= 16'h6141;
        40'h00002007f4: rom_data <= 16'hffff;
        40'h00002007f5: rom_data <= 16'hffff;
        40'h00002007f6: rom_data <= 16'hffff;
        40'h00002007f7: rom_data <= 16'hffff;
        40'h00002007ff: rom_data <= 16'haa55;
        40'h00002008ff: rom_data <= 16'haa55;
        40'h0000319400: rom_data <= 16'hfff8;
        40'h0000319401: rom_data <= 16'h0fff;
        40'h0000319402: rom_data <= 16'hffff;
        40'h0000319403: rom_data <= 16'hffff;
        40'h0000319404: rom_data <= 16'hffff;
        40'h0000319405: rom_data <= 16'h0fff;
        40'h0000319406: rom_data <= 16'hffff;
        40'h0000319407: rom_data <= 16'h0fff;
        40'h0000319408: rom_data <= 16'hffff;
        40'h0000319409: rom_data <= 16'h0fff;
        40'h000031940a: rom_data <= 16'hffff;
        40'h000031940b: rom_data <= 16'h0fff;
        40'h000031940c: rom_data <= 16'hffff;
        40'h000031940d: rom_data <= 16'h0fff;
        40'h000038ca00: rom_data <= 16'hfff8;
        40'h000038ca01: rom_data <= 16'h0fff;
        40'h000038ca02: rom_data <= 16'hffff;
        40'h000038ca03: rom_data <= 16'hffff;
        40'h000038ca04: rom_data <= 16'hffff;
        40'h000038ca05: rom_data <= 16'h0fff;
        40'h000038ca06: rom_data <= 16'hffff;
        40'h000038ca07: rom_data <= 16'h0fff;
        40'h000038ca08: rom_data <= 16'hffff;
        40'h000038ca09: rom_data <= 16'h0fff;
        40'h000038ca0a: rom_data <= 16'hffff;
        40'h000038ca0b: rom_data <= 16'h0fff;
        40'h000038ca0c: rom_data <= 16'hffff;
        40'h000038ca0d: rom_data <= 16'h0fff;
        40'h0000400000: rom_data <= 16'h2042;
        40'h0000400001: rom_data <= 16'h4900;
        40'h0000400002: rom_data <= 16'h6e00;
        40'h0000400003: rom_data <= 16'h6600;
        40'h0000400004: rom_data <= 16'h6f00;
        40'h0000400005: rom_data <= 16'h0f00;
        40'h0000400006: rom_data <= 16'h7200;
        40'h0000400007: rom_data <= 16'h0072;
        40'h0000400008: rom_data <= 16'h006d;
        40'h0000400009: rom_data <= 16'h0061;
        40'h000040000a: rom_data <= 16'h0074;
        40'h000040000b: rom_data <= 16'h0069;
        40'h000040000c: rom_data <= 16'h006f;
        40'h000040000e: rom_data <= 16'h006e;
        40'h0000400010: rom_data <= 16'h5301;
        40'h0000400011: rom_data <= 16'h7900;
        40'h0000400012: rom_data <= 16'h7300;
        40'h0000400013: rom_data <= 16'h7400;
        40'h0000400014: rom_data <= 16'h6500;
        40'h0000400015: rom_data <= 16'h0f00;
        40'h0000400016: rom_data <= 16'h7200;
        40'h0000400017: rom_data <= 16'h006d;
        40'h0000400018: rom_data <= 16'h0020;
        40'h0000400019: rom_data <= 16'h0056;
        40'h000040001a: rom_data <= 16'h006f;
        40'h000040001b: rom_data <= 16'h006c;
        40'h000040001c: rom_data <= 16'h0075;
        40'h000040001e: rom_data <= 16'h006d;
        40'h000040001f: rom_data <= 16'h0065;
        40'h0000400020: rom_data <= 16'h5953;
        40'h0000400021: rom_data <= 16'h5453;
        40'h0000400022: rom_data <= 16'h4d45;
        40'h0000400023: rom_data <= 16'h317e;
        40'h0000400024: rom_data <= 16'h2020;
        40'h0000400025: rom_data <= 16'h1620;
        40'h0000400026: rom_data <= 16'h9200;
        40'h0000400027: rom_data <= 16'h91a7;
        40'h0000400028: rom_data <= 16'h4f2a;
        40'h0000400029: rom_data <= 16'h4f2a;
        40'h000040002b: rom_data <= 16'h91a8;
        40'h000040002c: rom_data <= 16'h4f2a;
        40'h000040002d: rom_data <= 16'h0003;
        40'h0000400030: rom_data <= 16'h5845;
        40'h0000400031: rom_data <= 16'h4d41;
        40'h0000400032: rom_data <= 16'h4c50;
        40'h0000400033: rom_data <= 16'h2045;
        40'h0000400034: rom_data <= 16'h5854;
        40'h0000400035: rom_data <= 16'h2054;
        40'h0000400036: rom_data <= 16'h9418;
        40'h0000400037: rom_data <= 16'h91c7;
        40'h0000400038: rom_data <= 16'h4f2a;
        40'h0000400039: rom_data <= 16'h4f2a;
        40'h000040003b: rom_data <= 16'h91ba;
        40'h000040003c: rom_data <= 16'h4f2a;
        40'h000040003d: rom_data <= 16'h0006;
        40'h000040003e: rom_data <= 16'h0019;
        40'h0000404000: rom_data <= 16'h202e;
        40'h0000404001: rom_data <= 16'h2020;
        40'h0000404002: rom_data <= 16'h2020;
        40'h0000404003: rom_data <= 16'h2020;
        40'h0000404004: rom_data <= 16'h2020;
        40'h0000404005: rom_data <= 16'h1020;
        40'h0000404006: rom_data <= 16'h9200;
        40'h0000404007: rom_data <= 16'h91a7;
        40'h0000404008: rom_data <= 16'h4f2a;
        40'h0000404009: rom_data <= 16'h4f2a;
        40'h000040400b: rom_data <= 16'h91a8;
        40'h000040400c: rom_data <= 16'h4f2a;
        40'h000040400d: rom_data <= 16'h0003;
        40'h0000404010: rom_data <= 16'h2e2e;
        40'h0000404011: rom_data <= 16'h2020;
        40'h0000404012: rom_data <= 16'h2020;
        40'h0000404013: rom_data <= 16'h2020;
        40'h0000404014: rom_data <= 16'h2020;
        40'h0000404015: rom_data <= 16'h1020;
        40'h0000404016: rom_data <= 16'h9200;
        40'h0000404017: rom_data <= 16'h91a7;
        40'h0000404018: rom_data <= 16'h4f2a;
        40'h0000404019: rom_data <= 16'h4f2a;
        40'h000040401b: rom_data <= 16'h91a8;
        40'h000040401c: rom_data <= 16'h4f2a;
        40'h0000404020: rom_data <= 16'h7442;
        40'h0000404022: rom_data <= 16'hff00;
        40'h0000404023: rom_data <= 16'hffff;
        40'h0000404024: rom_data <= 16'hffff;
        40'h0000404025: rom_data <= 16'h0fff;
        40'h0000404026: rom_data <= 16'hce00;
        40'h0000404027: rom_data <= 16'hffff;
        40'h0000404028: rom_data <= 16'hffff;
        40'h0000404029: rom_data <= 16'hffff;
        40'h000040402a: rom_data <= 16'hffff;
        40'h000040402b: rom_data <= 16'hffff;
        40'h000040402c: rom_data <= 16'hffff;
        40'h000040402e: rom_data <= 16'hffff;
        40'h000040402f: rom_data <= 16'hffff;
        40'h0000404030: rom_data <= 16'h5701;
        40'h0000404031: rom_data <= 16'h5000;
        40'h0000404032: rom_data <= 16'h5300;
        40'h0000404033: rom_data <= 16'h6500;
        40'h0000404034: rom_data <= 16'h7400;
        40'h0000404035: rom_data <= 16'h0f00;
        40'h0000404036: rom_data <= 16'hce00;
        40'h0000404037: rom_data <= 16'h0074;
        40'h0000404038: rom_data <= 16'h0069;
        40'h0000404039: rom_data <= 16'h006e;
        40'h000040403a: rom_data <= 16'h0067;
        40'h000040403b: rom_data <= 16'h0073;
        40'h000040403c: rom_data <= 16'h002e;
        40'h000040403e: rom_data <= 16'h0064;
        40'h000040403f: rom_data <= 16'h0061;
        40'h0000404040: rom_data <= 16'h5057;
        40'h0000404041: rom_data <= 16'h4553;
        40'h0000404042: rom_data <= 16'h5454;
        40'h0000404043: rom_data <= 16'h317e;
        40'h0000404044: rom_data <= 16'h4144;
        40'h0000404045: rom_data <= 16'h2054;
        40'h0000404046: rom_data <= 16'h9500;
        40'h0000404047: rom_data <= 16'h91a7;
        40'h0000404048: rom_data <= 16'h4f2a;
        40'h0000404049: rom_data <= 16'h4f2a;
        40'h000040404b: rom_data <= 16'h91a8;
        40'h000040404c: rom_data <= 16'h4f2a;
        40'h000040404d: rom_data <= 16'h0004;
        40'h000040404e: rom_data <= 16'h000c;
        40'h0000404050: rom_data <= 16'h4742;
        40'h0000404051: rom_data <= 16'h7500;
        40'h0000404052: rom_data <= 16'h6900;
        40'h0000404053: rom_data <= 16'h6400;
        40'h0000404055: rom_data <= 16'h0f00;
        40'h0000404056: rom_data <= 16'hff00;
        40'h0000404057: rom_data <= 16'hffff;
        40'h0000404058: rom_data <= 16'hffff;
        40'h0000404059: rom_data <= 16'hffff;
        40'h000040405a: rom_data <= 16'hffff;
        40'h000040405b: rom_data <= 16'hffff;
        40'h000040405c: rom_data <= 16'hffff;
        40'h000040405e: rom_data <= 16'hffff;
        40'h000040405f: rom_data <= 16'hffff;
        40'h0000404060: rom_data <= 16'h4901;
        40'h0000404061: rom_data <= 16'h6e00;
        40'h0000404062: rom_data <= 16'h6400;
        40'h0000404063: rom_data <= 16'h6500;
        40'h0000404064: rom_data <= 16'h7800;
        40'h0000404065: rom_data <= 16'h0f00;
        40'h0000404066: rom_data <= 16'hff00;
        40'h0000404067: rom_data <= 16'h0065;
        40'h0000404068: rom_data <= 16'h0072;
        40'h0000404069: rom_data <= 16'h0056;
        40'h000040406a: rom_data <= 16'h006f;
        40'h000040406b: rom_data <= 16'h006c;
        40'h000040406c: rom_data <= 16'h0075;
        40'h000040406e: rom_data <= 16'h006d;
        40'h000040406f: rom_data <= 16'h0065;
        40'h0000404070: rom_data <= 16'h4e49;
        40'h0000404071: rom_data <= 16'h4544;
        40'h0000404072: rom_data <= 16'h4558;
        40'h0000404073: rom_data <= 16'h317e;
        40'h0000404074: rom_data <= 16'h2020;
        40'h0000404075: rom_data <= 16'h2020;
        40'h0000404076: rom_data <= 16'h6600;
        40'h0000404077: rom_data <= 16'h91a8;
        40'h0000404078: rom_data <= 16'h4f2a;
        40'h0000404079: rom_data <= 16'h4f2a;
        40'h000040407b: rom_data <= 16'h91a9;
        40'h000040407c: rom_data <= 16'h4f2a;
        40'h000040407d: rom_data <= 16'h0005;
        40'h000040407e: rom_data <= 16'h004c;
        40'h0000408000: rom_data <= 16'h000c;
        40'h0000408002: rom_data <= 16'h19b9;
        40'h0000408003: rom_data <= 16'h2cb8;
        40'h0000408004: rom_data <= 16'ha4d9;
        40'h0000408005: rom_data <= 16'h8fea;
        40'h000040c000: rom_data <= 16'h007b;
        40'h000040c001: rom_data <= 16'h0038;
        40'h000040c002: rom_data <= 16'h0036;
        40'h000040c003: rom_data <= 16'h0037;
        40'h000040c004: rom_data <= 16'h0044;
        40'h000040c005: rom_data <= 16'h0033;
        40'h000040c006: rom_data <= 16'h0033;
        40'h000040c007: rom_data <= 16'h0031;
        40'h000040c008: rom_data <= 16'h0046;
        40'h000040c009: rom_data <= 16'h002d;
        40'h000040c00a: rom_data <= 16'h0034;
        40'h000040c00b: rom_data <= 16'h0031;
        40'h000040c00c: rom_data <= 16'h0031;
        40'h000040c00d: rom_data <= 16'h0036;
        40'h000040c00e: rom_data <= 16'h002d;
        40'h000040c00f: rom_data <= 16'h0034;
        40'h000040c010: rom_data <= 16'h0038;
        40'h000040c011: rom_data <= 16'h0035;
        40'h000040c012: rom_data <= 16'h0039;
        40'h000040c013: rom_data <= 16'h002d;
        40'h000040c014: rom_data <= 16'h0039;
        40'h000040c015: rom_data <= 16'h0034;
        40'h000040c016: rom_data <= 16'h0046;
        40'h000040c017: rom_data <= 16'h0031;
        40'h000040c018: rom_data <= 16'h002d;
        40'h000040c019: rom_data <= 16'h0045;
        40'h000040c01a: rom_data <= 16'h0036;
        40'h000040c01b: rom_data <= 16'h0032;
        40'h000040c01c: rom_data <= 16'h0037;
        40'h000040c01d: rom_data <= 16'h0034;
        40'h000040c01e: rom_data <= 16'h0046;
        40'h000040c01f: rom_data <= 16'h0032;
        40'h000040c020: rom_data <= 16'h0034;
        40'h000040c021: rom_data <= 16'h0030;
        40'h000040c022: rom_data <= 16'h0035;
        40'h000040c023: rom_data <= 16'h0043;
        40'h000040c024: rom_data <= 16'h0032;
        40'h000040c025: rom_data <= 16'h007d;
        40'h0000410000: rom_data <= 16'h6548;
        40'h0000410001: rom_data <= 16'h6c6c;
        40'h0000410002: rom_data <= 16'h206f;
        40'h0000410003: rom_data <= 16'h6f77;
        40'h0000410004: rom_data <= 16'h6c72;
        40'h0000410005: rom_data <= 16'h2164;
        40'h0000410006: rom_data <= 16'h0a0d;
        40'h0000410007: rom_data <= 16'h7449;
        40'h0000410008: rom_data <= 16'h7720;
        40'h0000410009: rom_data <= 16'h726f;
        40'h000041000a: rom_data <= 16'h736b;
        40'h000041000b: rom_data <= 16'h0d21;
        40'h000041000c: rom_data <= 16'h000a;
        default:        rom_data <= 16'h0000;
        endcase


endmodule
