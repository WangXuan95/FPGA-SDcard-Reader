
//--------------------------------------------------------------------------------------------------------
// Module  : sd_fake
// Type    : synthesizable, IP's top
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: Imitate a SDHCv2 Read-Only SD card
//--------------------------------------------------------------------------------------------------------

module sd_fake (
    input  wire         rstn_async,
    // SD-card signals, connect to a SD-host, such as a SDcard Reader
    input  wire         sdclk,
    inout               sdcmd,
    output wire [ 3:0]  sddat,
    // data read interface, connect to a RAM which contains SD-card's data.
    output reg          rdreq,
    output reg  [39:0]  rdaddr,
    input  wire [15:0]  rddata,
    // show status (optional)
    output wire [ 7:0]  show_status_bits,
    // show parsed request command on sdcmd (optional)
    output reg          show_sdcmd_en,
    output reg  [ 5:0]  show_sdcmd_cmd,
    output reg  [31:0]  show_sdcmd_arg
);

initial rdreq = '0;
initial rdaddr = '0;

initial show_sdcmd_en  = '0;
initial show_sdcmd_cmd = '0;
initial show_sdcmd_arg = '0;


// generate reset sync with posedge of sdclk
reg       rstn_sdclk_p = '0;
reg [1:0] rstn_sdclk_p_l = '0;
always @ (posedge sdclk or negedge rstn_async)
    if(~rstn_async)
        {rstn_sdclk_p, rstn_sdclk_p_l} <= '0;
    else
        {rstn_sdclk_p, rstn_sdclk_p_l} <= {rstn_sdclk_p_l, 1'b1};


// generate reset sync with negedge of sdclk
reg       rstn_sdclk_n = '0;
reg [1:0] rstn_sdclk_n_l = '0;
always @ (negedge sdclk or negedge rstn_async)
    if(~rstn_async)
        {rstn_sdclk_n, rstn_sdclk_n_l} <= '0;
    else
        {rstn_sdclk_n, rstn_sdclk_n_l} <= {rstn_sdclk_n_l, 1'b1};



reg        sdcmdoe  = 1'b0;
reg        sdcmdout = 1'b1;
reg        sddatoe  = 1'b0;
reg  [3:0] sddatout = '1;

assign sdcmd = sdcmdoe ? sdcmdout : 1'bz;
assign sddat = sddatoe ? sddatout : 4'bz;

function automatic logic [ 6:0] CalcCrcCMD(input [ 6:0] crc, input inbit);
    return {crc[5:0],crc[6]^inbit} ^ {3'b0,crc[6]^inbit,3'b0};
endfunction

function automatic logic [15:0] CalcCrcDAT(input [15:0] crc, input inbit);
    return {crc[14:0],crc[15]^inbit} ^ {3'b0,crc[15]^inbit,6'b0,crc[15]^inbit,5'b0};
endfunction

localparam         BLOCK_SIZE = 512;     // 512B per block
localparam [ 15:0] RCA_REG = 16'h0013;

localparam [ 31:0] OCR_REG = {1'b1,1'b1,6'b0,9'h1ff,7'b0,1'b0,7'b0}; // not busy, CCS=1(SDHC card), all voltage, not dual-voltage card

localparam [119:0] CID_REG = 120'h02544d53_41303847_14394a67_c700e4;

localparam [119:0] CSD_REG = 120'h400e0032_50590000_39b73f80_000030; // 25MHz, SD-ROM card
                          // 120'h400e0032_5b590000_39b77f80_0a4000; // 25MHz, Normal card
                               
localparam [ 64:0] SCR_REG = 64'h0005_0000_00000000;
                          // 64'h0201_0000_00000000;  // SD-ROM card, disable 4-bit bus mode
                          // 64'h0205_0000_00000000;  // SD-ROM card, enable  4-bit bus mode
                          // 64'h0231_0000_00000000;  // Normal card, disable 4-bit bus mode
                          // 64'h0235_0000_00000000;  // Normal card, enable  4-bit bus mode

reg last_is_acmd=1'b0;

enum logic [1:0] {WAITINGCMD, LOADRESP, RESPING} respstate = WAITINGCMD;

struct packed{
    logic [ 3:0] pre_st;
    logic [ 5:0] cmd;
    logic [31:0] arg;
    logic [ 6:0] crc;
    logic        stop;
} request = '0;

typedef enum logic [3:0] {IDLE, READY, IDENT, STBY, TRAN, DATA, RCV, PRG, DIS} current_state_t;

struct packed{
    logic out_of_range;
    logic address_error;
    logic block_len_error;
    logic erase_seq_error;
    logic erase_param;
    logic wp_violation;
    logic card_is_locked;
    logic lock_unlock_failed;
    logic com_crc_error;
    logic illegal_command;
    logic card_ecc_failed;
    logic cc_error;
    logic error;
    logic [1:0] rsvd1;   // reserved
    logic csd_overwrite;
    logic wp_erase_skip;
    logic card_ecc_disabled;
    logic erase_reset;
    current_state_t current_state;
    logic ready_for_data;
    logic [1:0] rsvd2;
    logic app_cmd;
    logic rsvd3;
    logic ake_seq_error;
    logic [2:0] rsvd4;
} cardstatus = '0;
wire [15:0] cardstatus_short = {cardstatus[23:22], cardstatus[19], cardstatus[12:0]};  // for R6 (CMD3)

localparam HIGHZLEN = 1;
localparam WAITLEN  = HIGHZLEN + 3;
reg [  5:0] cmd='0;
reg [119:0] arg='0;
reg [  6:0] crc='0;

reg response_end = 1'b0;
reg valid='0, dummycrc='0;
int idx=0, arglen=0;

task automatic response_init(input _valid, input _dummycrc, input [5:0] _cmd, input int _arglen, input [119:0] _arg);
    cmd          = _cmd;
    arg          = _arg;
    crc          = '0;
    valid        = _valid;
    dummycrc     = _dummycrc;
    idx          = 0;
    arglen       = _arglen;
    response_end = 1'b0;
endtask

task automatic response_yield;
    response_end = 1'b0;
    if         (      ~valid) begin
        sdcmdoe  = 0;
        sdcmdout = 1;
        response_end = 1'b1;
    end else if(idx<HIGHZLEN) begin
        sdcmdoe  = 0;
        sdcmdout = 1;
    end else if(idx<WAITLEN) begin
        sdcmdoe  = 1;
        sdcmdout = 1;
    end else if(idx<WAITLEN+2) begin
        sdcmdoe  = 1;
        sdcmdout = 0;
        crc = CalcCrcCMD(crc, sdcmdout);
    end else if(idx<WAITLEN+2+6) begin
        sdcmdoe  = 1;
        sdcmdout = cmd[ (WAITLEN+2+6)-1-idx ];
        crc = CalcCrcCMD(crc, sdcmdout);
    end else if(idx<WAITLEN+2+6+arglen) begin
        sdcmdoe  = 1;
        sdcmdout = arg[ (WAITLEN+2+6+arglen)-1-idx ];
        crc = CalcCrcCMD(crc, sdcmdout);
    end else if(idx<WAITLEN+2+6+arglen+7) begin
        sdcmdoe  = 1;
        sdcmdout = dummycrc ? 1'b1 : crc[ (WAITLEN+2+6+arglen+7)-1-idx ];
    end else if(idx<WAITLEN+2+6+arglen+8) begin
        sdcmdoe  = 1;
        sdcmdout = 1;
    end else begin
        sdcmdoe  = 0;
        sdcmdout = 1;
        response_end = 1'b1;
    end
    if(~response_end) idx++;
endtask

localparam DATAWAITLEN  = HIGHZLEN    + 16;
localparam DATASTARTLEN = DATAWAITLEN + 1;
reg          read_task=0, read_continue=0, read_scr=0, read_sdstat=0, read_cmd6stat=0;
reg   [31:0] read_idx = 0;
wire  [31:0] read_byte_idx = (read_idx-DATASTARTLEN);
wire  [ 3:0] readbyteidx = 4'hf - read_byte_idx[3:0];
wire  [ 1:0] readquadidx = 2'h3 - read_byte_idx[1:0];
reg   [15:0] read_crc = 0;
reg   [15:0] read_crc_wide[4];
wire  [15:0] rddata_reversed = {rddata[7:0], rddata[15:8]};
reg          widebus = 1'b0;  // 0:1bit Mode  1:4bit Mode

wire [511:0] SD_STAT   = { widebus,1'b0, 1'b0, 13'h0, // bus-width, no security mode
                           16'h0001,                  // SD-ROM
                           32'h00000000,
                            8'h02,                    // speed class: class-4
                            8'hff,
                            4'h9,
                          428'h0    };

reg  [5:0] cmd6_invalid = 6'h0;
wire [511:0] CMD6_RESP = { 12'h0, (~(|cmd6_invalid)), 3'h0,  // 8mA when not invalid
                           16'h8001,           16'h8001,           16'h8001,           16'h8001,           16'h8001,           16'h8001,
                           {4{cmd6_invalid[5]}}, {4{cmd6_invalid[4]}}, {4{cmd6_invalid[3]}}, {4{cmd6_invalid[2]}}, {4{cmd6_invalid[1]}}, {4{cmd6_invalid[0]}}, 
                          376'h0   };

assign show_status_bits = { response_end, widebus, cardstatus.ready_for_data, cardstatus.app_cmd, cardstatus.current_state };

task automatic data_response_init(input [31:0] _read_sector_no=0, input _read_continue=1'b0);
    read_task      = 1;
    read_continue  = _read_continue;
    read_scr       = 0;
    read_sdstat    = 0;
    read_cmd6stat  = 0;
    rdaddr        <= {_read_sector_no,8'h0};
    read_idx       = 0;
    read_crc       = 0;
    for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
endtask

task automatic data_response_sdstat_init;
    read_task      = 1;
    read_continue  = 0;
    read_scr       = 0;
    read_sdstat    = 1;
    read_cmd6stat  = 0;
    rdaddr        <= '0;
    read_idx       = 0;
    read_crc       = 0;
    for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
endtask

task automatic data_response_cmd6stat_init;
    read_task      = 1;
    read_continue  = 0;
    read_scr       = 0;
    read_sdstat    = 0;
    read_cmd6stat  = 1;
    rdaddr        <= '0;
    read_idx       = 0;
    read_crc       = 0;
    for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
endtask

task automatic data_response_scr_init;
    read_task      = 1;
    read_continue  = 0;
    read_scr       = 1;
    read_sdstat    = 0;
    read_cmd6stat  = 0;
    rdaddr        <= '0;
    read_idx       = 0;
    read_crc       = 0;
    for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
endtask

task automatic data_response_stop;
    read_task      = 0;
    read_continue  = 0;
    read_scr       = 0;
    read_sdstat    = 0;
    read_cmd6stat  = 0;
    rdaddr        <= '0;
    read_idx       = 0;
    read_crc       = 0;
    for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
endtask

task automatic data_response_yield;
    rdreq <='0;
    sddatoe  = 1'b1;
    if(~read_task) begin
        sddatoe  = 1'b0;
        sddatout = 4'hf;
    end else if(read_idx<    HIGHZLEN) begin
        sddatoe  = 1'b0;
        sddatout = 4'hf;
    end else if(read_idx< DATAWAITLEN) begin
        sddatout = 4'hf;
    end else if(read_idx<DATASTARTLEN) begin
        sddatout = 4'h0;
        read_crc = 0;
        for(int i=0;i<4;i++) read_crc_wide[i]  = '0;
        rdreq   <= ~ ( read_scr | read_sdstat | read_cmd6stat );
    end else if( read_sdstat | read_cmd6stat ) begin // the read task is reading a SD_STAT register or CMD6_RESP
        if(widebus) begin
            if         (read_idx<DATASTARTLEN+128) begin
                if(read_cmd6stat)
                    sddatout =  CMD6_RESP[ ((DATASTARTLEN+128)-1-read_idx)*4 +: 4 ];
                else
                    sddatout =  SD_STAT[ ((DATASTARTLEN+128)-1-read_idx)*4 +: 4 ];
                for(int i=0;i<4;i++) read_crc_wide[i] = CalcCrcDAT(read_crc_wide[i],sddatout[i]);
            end else if(read_idx<DATASTARTLEN+128+16) begin
                for(int i=0;i<4;i++) sddatout[i] = read_crc_wide[i][ (DATASTARTLEN+128+16)-1-read_idx ];
            end else begin
                sddatout = 4'hf;
                read_task = 0;
            end
        end else begin
            if         (read_idx<DATASTARTLEN+512) begin
                if(read_cmd6stat)
                    sddatout = {3'b111, CMD6_RESP[ (DATASTARTLEN+512)-1-read_idx ] };
                else
                    sddatout = {3'b111, SD_STAT[ (DATASTARTLEN+512)-1-read_idx ] };
                read_crc = CalcCrcDAT(read_crc,sddatout[0]);
            end else if(read_idx<DATASTARTLEN+512+16) begin
                sddatout = {3'b111, read_crc[ (DATASTARTLEN+512+16)-1-read_idx ]};
            end else begin
                sddatout = 4'hf;
                read_task = 0;
            end
        end
    end else if(read_scr) begin   // the read task is reading a SCR register
        if(widebus) begin
            if         (read_idx<DATASTARTLEN+16) begin
                sddatout =  SCR_REG[ ((DATASTARTLEN+16)-1-read_idx)*4 +: 4 ];
                for(int i=0;i<4;i++) read_crc_wide[i] = CalcCrcDAT(read_crc_wide[i], sddatout[i]);
            end else if(read_idx<DATASTARTLEN+16+16) begin
                for(int i=0;i<4;i++) sddatout[i] = read_crc_wide[i][ (DATASTARTLEN+16+16)-1-read_idx ];
            end else begin
                sddatout = 4'hf;
                read_task = 0;
            end
        end else begin
            if         (read_idx<DATASTARTLEN+64) begin
                sddatout = {3'b111, SCR_REG[ (DATASTARTLEN+64)-1-read_idx ] };
                read_crc = CalcCrcDAT(read_crc,sddatout[0]);
            end else if(read_idx<DATASTARTLEN+64+16) begin
                sddatout = {3'b111, read_crc[ (DATASTARTLEN+64+16)-1-read_idx ]};
            end else begin
                sddatout = 4'hf;
                read_task = 0;
            end
        end
    end else begin                // the read task is reading data sector(s)
        if(widebus) begin
            if         (read_idx<DATASTARTLEN+(BLOCK_SIZE*2)) begin
                if( readquadidx==2'h3 ) begin
                    rdreq<=1'b0;  rdaddr <= rdaddr+40'h1;
                end else if( readquadidx==2'h0 ) begin
                    if(read_idx<DATASTARTLEN+(BLOCK_SIZE*2)-1) rdreq<=1'b1;
                end
                sddatout = rddata_reversed[readquadidx*4+:4];
                for(int i=0;i<4;i++) read_crc_wide[i] = CalcCrcDAT(read_crc_wide[i],sddatout[i]);
            end else if(read_idx<DATASTARTLEN+(BLOCK_SIZE*2)+16) begin
                for(int i=0;i<4;i++) sddatout[i] = read_crc_wide[i][ (DATASTARTLEN+(BLOCK_SIZE*2)+16)-1-read_idx ];
            end else begin
                sddatout = 4'hf;
                if(read_continue)
                    read_idx  = HIGHZLEN+1;
                else
                    read_task = 0;
            end
        end else begin
            if         (read_idx<DATASTARTLEN+(BLOCK_SIZE*8)) begin
                if( readbyteidx==4'hf ) begin
                    rdreq<=1'b0;  rdaddr <= rdaddr+40'h1;
                end else if( readbyteidx==4'h0 ) begin
                    if(read_idx<DATASTARTLEN+(BLOCK_SIZE*8)-1) rdreq<=1'b1;
                end
                sddatout = {3'b111, rddata_reversed[readbyteidx]};
                read_crc = CalcCrcDAT(read_crc,sddatout[0]);
            end else if(read_idx<DATASTARTLEN+(BLOCK_SIZE*8)+16) begin
                sddatout = {3'b111, read_crc[ (DATASTARTLEN+(BLOCK_SIZE*8)+16)-1-read_idx ]};
            end else begin
                sddatout = 4'hf;
                if(read_continue)
                    read_idx  = HIGHZLEN+1;
                else
                    read_task = 0;
            end
        end
    end
    if(read_task) begin
        read_idx++;
        cardstatus.current_state = DATA;
    end else if(cardstatus.current_state==DATA) 
        cardstatus.current_state = TRAN;
endtask

reg [6:0] cmdcrcval = '0;
always @ (*) begin
    cmdcrcval = '0;
    for(int i=47; i>0; i--) cmdcrcval = CalcCrcCMD(cmdcrcval, request[i]);
end
    
always @ (posedge sdclk or negedge rstn_sdclk_p)
    if(~rstn_sdclk_p) begin
        respstate <= WAITINGCMD;
        request   <= '1;
    end else begin
        case(respstate)
        WAITINGCMD:begin
                     if(request.pre_st==4'b1101 && request.stop) begin
                         if(cmdcrcval==7'd0)
                             respstate <= LOADRESP;
                         else
                             request   <= '1;
                     end else begin
                         request <= {request[48:0],sdcmd};
                     end
                   end
        LOADRESP  :  respstate <= RESPING;
        RESPING   :  if(response_end) begin
                         respstate <= WAITINGCMD;
                         request   <= '1;
                     end
        endcase
    end

always @ (negedge sdclk or negedge rstn_sdclk_n)
    if(~rstn_sdclk_n) begin
        response_init( 0, 0, 0, 0, 0 );
        data_response_stop;
        response_yield;
        data_response_yield;
        last_is_acmd <= 1'b0;
        cardstatus = '0;
        widebus = 0;
        cmd6_invalid <= 6'h0;
    end else begin
        if(respstate==LOADRESP) begin
            last_is_acmd      <= 1'b0;
            cardstatus.app_cmd = 1'b0;
            cardstatus.block_len_error = 1'b0;
            case(request.cmd)
            0       : begin                                                                           // GO_IDLE_STATE
                          response_init( 0, 0 ,           0 ,   0 ,   0                            ); //    there is NO RESPONSE for CMD0
                          data_response_stop;
                          response_yield;
                          data_response_yield;
                          last_is_acmd <= 1'b0;
                          cardstatus = '0;
                          cardstatus.ready_for_data = 1'b1;
                          widebus = 0;
                          cmd6_invalid <= 6'h0;
                      end
            2       : begin                                                                           // ALL_SEND_CID
                          response_init( 1, 0 ,   6'b000000 , 120 ,  CID_REG                       ); //    R2 TODO: why cmd=000000 instead of 111111 ???
                          cardstatus.current_state = IDENT;
                          cardstatus.illegal_command = 1'b0;
                      end
            3       : begin                                                                           // SEND_RELATIVE_ADDR(send RCA)
                          response_init( 1, 0 , request.cmd ,  32 ,  {RCA_REG,cardstatus_short}    ); //    R6
                          cardstatus.current_state = STBY;
                          cardstatus.illegal_command = 1'b0;
                      end
            4       : if(request.arg[15:0] == 16'h0) begin                                            // SET_DSR
                          response_init( 0, 0 ,           0 ,   0 ,   0                            ); //    there is NO RESPONSE for CMD4
                          cardstatus.illegal_command = 1'b0;
                      end
            6       : if(last_is_acmd && cardstatus.current_state==TRAN) begin                        // SET_BUS_WIDTH
                          cardstatus.app_cmd = 1'b1;
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          widebus = request.arg[1];
                          cardstatus.illegal_command = 1'b0;
                      end else if(cardstatus.current_state==TRAN) begin                               // SWITCH_FUNC
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cmd6_invalid[0] <= ( request.arg[0*4+:4]!=4'h0 && request.arg[0*4+:4]!=4'hf );
                          cmd6_invalid[1] <= ( request.arg[1*4+:4]!=4'h0 && request.arg[1*4+:4]!=4'hf );
                          cmd6_invalid[2] <= ( request.arg[2*4+:4]!=4'h0 && request.arg[2*4+:4]!=4'hf );
                          cmd6_invalid[3] <= ( request.arg[3*4+:4]!=4'h0 && request.arg[3*4+:4]!=4'hf );
                          cmd6_invalid[4] <= ( request.arg[4*4+:4]!=4'h0 && request.arg[4*4+:4]!=4'hf );
                          cmd6_invalid[5] <= ( request.arg[5*4+:4]!=4'h0 && request.arg[5*4+:4]!=4'hf );
                          data_response_cmd6stat_init;
                          cardstatus.illegal_command = 1'b0;
                      end
            7       : if(request.arg[31:16] == RCA_REG) begin                                         // SELECT_CARD
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cardstatus.current_state = TRAN;
                          cardstatus.illegal_command = 1'b0;
                      end else begin                                                                  // DESELECT_CARD
                          cardstatus.current_state = STBY;
                          cardstatus.illegal_command = 1'b0;
                      end
            8       : begin                                                                           // SEND_IF_COND
                          response_init( 1, 0 , request.cmd ,  32 ,  {24'd1,request.arg[7:0]}      );
                          cardstatus.illegal_command = 1'b0;
                      end
            9       : if(request.arg[31:16]==RCA_REG) begin                                           // SEND_CSD
                          response_init( 1, 0 ,   6'b000000 , 120 ,  CSD_REG                       );
                          cardstatus.illegal_command = 1'b0;
                      end
            10      : if(request.arg[31:16]==RCA_REG) begin                                           // SEND_CID
                          response_init( 1, 0 ,   6'b000000 , 120 ,  CID_REG                       );
                          cardstatus.illegal_command = 1'b0;
                      end
            12      : if(cardstatus.current_state==DATA) begin                                        // STOP_TRANSMISSION
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          data_response_stop;
                          cardstatus.illegal_command = 1'b0;
                      end
            13      : if(last_is_acmd) begin                                                          // SEND_SD_STATUS
                          if(cardstatus.current_state==TRAN) begin
                              cardstatus.app_cmd = 1'b1;
                              response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                );
                              data_response_sdstat_init;
                              cardstatus.illegal_command = 1'b0;
                          end
                      end else if(request.arg[31:16]==RCA_REG) begin                                  // SEND_STATUS
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cardstatus.illegal_command = 1'b0;
                      end
            15      : if(request.arg[31:16]==RCA_REG) begin                                           // GO_INACTIVE_STATE
                          response_init( 0, 0 ,           0 ,   0 ,   0                            );
                          cardstatus.current_state = IDLE;
                          cardstatus.illegal_command = 1'b0;
                      end
            16      : if(cardstatus.current_state==TRAN) begin                                        // SET_BLOCKLEN
                          if(request.arg > 512) cardstatus.block_len_error = 1'b1;
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cardstatus.illegal_command = 1'b0;
                      end
            17      : if(cardstatus.current_state==TRAN) begin                                        // READ_SINGLE_BLOCK
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          data_response_init(request.arg);
                          cardstatus.illegal_command = 1'b0;
                      end
            18      : if(cardstatus.current_state==TRAN) begin                                        // READ_MULTIPLE_BLOCK
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          data_response_init(request.arg, 1);
                          cardstatus.illegal_command = 1'b0;
                      end
            55      : if(request.arg[31:16]=='0 || request.arg[31:16]==RCA_REG) begin                 // APP_CMD
                          last_is_acmd <= 1'b1;
                          cardstatus.app_cmd = 1'b1;
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cardstatus.illegal_command = 1'b0;
                      end
            41      : if(last_is_acmd) begin                                                          // SD_SEND_OP_COND
                          cardstatus.app_cmd = 1'b1;
                          response_init( 1, 1 ,   6'b111111 ,  32 ,  OCR_REG                       );
                          cardstatus.illegal_command = 1'b0;
                      end
            42      : if(last_is_acmd) begin                                                          // SET_CLR_CARD_DETECT
                          cardstatus.app_cmd = 1'b1;
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          cardstatus.illegal_command = 1'b0;
                      end
            51      : if(last_is_acmd &&  cardstatus.current_state==TRAN) begin                       // SEND_SCR
                          cardstatus.app_cmd = 1'b1;
                          response_init( 1, 0 , request.cmd ,  32 ,  cardstatus                    );
                          data_response_scr_init;
                          cardstatus.illegal_command = 1'b0;
                      end
            default : begin                                                                           // undefined CMD
                          response_init( 0, 0 ,           0 ,   0 ,   0                            );
                          cardstatus.illegal_command = 1'b1;
                      end
            endcase
        end
        response_yield;
        data_response_yield;
    end


always @ (posedge sdclk or negedge rstn_sdclk_p)
    if(~rstn_sdclk_p) begin
        show_sdcmd_en  <= 1'b0;
        show_sdcmd_cmd <= '0;
        show_sdcmd_arg <= '0;
    end else begin
        show_sdcmd_en  <= 1'b0;
        if(respstate == LOADRESP) begin
            show_sdcmd_en  <= 1'b1;
            show_sdcmd_cmd <= request.cmd;
            show_sdcmd_arg <= request.arg;
        end
    end

endmodule
