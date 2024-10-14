///////////////////////////////////////////////////////////////////////////
//NOTE: This file has been automatically generated by Vivado.
///////////////////////////////////////////////////////////////////////////
`timescale 1ps/1ps
package design_1_axi_vip_1_0_pkg;
import axi_vip_pkg::*;
///////////////////////////////////////////////////////////////////////////
// These parameters are named after the component for use in your verification 
// environment.
///////////////////////////////////////////////////////////////////////////
      parameter design_1_axi_vip_1_0_VIP_PROTOCOL           = 2;
      parameter design_1_axi_vip_1_0_VIP_READ_WRITE_MODE    = "READ_WRITE";
      parameter design_1_axi_vip_1_0_VIP_INTERFACE_MODE     = 2;
      parameter design_1_axi_vip_1_0_VIP_ADDR_WIDTH         = 32;
      parameter design_1_axi_vip_1_0_VIP_DATA_WIDTH         = 32;
      parameter design_1_axi_vip_1_0_VIP_ID_WIDTH           = 0;
      parameter design_1_axi_vip_1_0_VIP_AWUSER_WIDTH       = 0;
      parameter design_1_axi_vip_1_0_VIP_ARUSER_WIDTH       = 0;
      parameter design_1_axi_vip_1_0_VIP_RUSER_WIDTH        = 0;
      parameter design_1_axi_vip_1_0_VIP_WUSER_WIDTH        = 0;
      parameter design_1_axi_vip_1_0_VIP_BUSER_WIDTH        = 0;
      parameter design_1_axi_vip_1_0_VIP_SUPPORTS_NARROW    = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_BURST          = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_LOCK           = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_CACHE          = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_REGION         = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_QOS            = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_PROT           = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_WSTRB          = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_BRESP          = 1;
      parameter design_1_axi_vip_1_0_VIP_HAS_RRESP          = 1;
      parameter design_1_axi_vip_1_0_VIP_HAS_ACLKEN         = 0;
      parameter design_1_axi_vip_1_0_VIP_HAS_ARESETN        = 1;
///////////////////////////////////////////////////////////////////////////


typedef axi_slv_agent #(design_1_axi_vip_1_0_VIP_PROTOCOL, 
                        design_1_axi_vip_1_0_VIP_ADDR_WIDTH,
                        design_1_axi_vip_1_0_VIP_DATA_WIDTH,
                        design_1_axi_vip_1_0_VIP_DATA_WIDTH,
                        design_1_axi_vip_1_0_VIP_ID_WIDTH,
                        design_1_axi_vip_1_0_VIP_ID_WIDTH,
                        design_1_axi_vip_1_0_VIP_AWUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_WUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_BUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_ARUSER_WIDTH,
                        design_1_axi_vip_1_0_VIP_RUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_SUPPORTS_NARROW, 
                        design_1_axi_vip_1_0_VIP_HAS_BURST,
                        design_1_axi_vip_1_0_VIP_HAS_LOCK,
                        design_1_axi_vip_1_0_VIP_HAS_CACHE,
                        design_1_axi_vip_1_0_VIP_HAS_REGION,
                        design_1_axi_vip_1_0_VIP_HAS_PROT,
                        design_1_axi_vip_1_0_VIP_HAS_QOS,
                        design_1_axi_vip_1_0_VIP_HAS_WSTRB,
                        design_1_axi_vip_1_0_VIP_HAS_BRESP,
                        design_1_axi_vip_1_0_VIP_HAS_RRESP,
                        design_1_axi_vip_1_0_VIP_HAS_ARESETN) design_1_axi_vip_1_0_slv_t;

typedef axi_slv_mem_agent #(design_1_axi_vip_1_0_VIP_PROTOCOL, 
                        design_1_axi_vip_1_0_VIP_ADDR_WIDTH,
                        design_1_axi_vip_1_0_VIP_DATA_WIDTH,
                        design_1_axi_vip_1_0_VIP_DATA_WIDTH,
                        design_1_axi_vip_1_0_VIP_ID_WIDTH,
                        design_1_axi_vip_1_0_VIP_ID_WIDTH,
                        design_1_axi_vip_1_0_VIP_AWUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_WUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_BUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_ARUSER_WIDTH,
                        design_1_axi_vip_1_0_VIP_RUSER_WIDTH, 
                        design_1_axi_vip_1_0_VIP_SUPPORTS_NARROW, 
                        design_1_axi_vip_1_0_VIP_HAS_BURST,
                        design_1_axi_vip_1_0_VIP_HAS_LOCK,
                        design_1_axi_vip_1_0_VIP_HAS_CACHE,
                        design_1_axi_vip_1_0_VIP_HAS_REGION,
                        design_1_axi_vip_1_0_VIP_HAS_PROT,
                        design_1_axi_vip_1_0_VIP_HAS_QOS,
                        design_1_axi_vip_1_0_VIP_HAS_WSTRB,
                        design_1_axi_vip_1_0_VIP_HAS_BRESP,
                        design_1_axi_vip_1_0_VIP_HAS_RRESP,
                        design_1_axi_vip_1_0_VIP_HAS_ARESETN) design_1_axi_vip_1_0_slv_mem_t;
                        
      
///////////////////////////////////////////////////////////////////////////
// How to start the verification component
///////////////////////////////////////////////////////////////////////////
//      design_1_axi_vip_1_0_slv_t  design_1_axi_vip_1_0_slv;
//      initial begin : START_design_1_axi_vip_1_0_SLAVE
//        design_1_axi_vip_1_0_slv = new("design_1_axi_vip_1_0_slv", `design_1_axi_vip_1_0_PATH_TO_INTERFACE);
//        design_1_axi_vip_1_0_slv.start_slave();
//      end

endpackage : design_1_axi_vip_1_0_pkg
