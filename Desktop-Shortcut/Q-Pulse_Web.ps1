$Temppath = "C:\Temp"
If(!(test-path $Temppath))
{
      New-Item -ItemType Directory -Force -Path $Temppath
}

#Icon_File
# Picture Base64
# Create the Icon File object from a base64 code - HeroImage.

$Picture_Base64 = "AAABAAMAEBAAAAEAIABoBAAANgAAACAgAAABACAAqBAAAJ4EAAAwMAAAAQAgAKglAABGFQAAKAAAABAAAAAgAAAAAQAgAAAAAAAABAAAEgsAABILAAAAAAAAAAAAAP/////+/v7//v39///////j0Nv/rHKU/44+bP+BKFv/gSdb/4k1Zf+veJj//v3+//79/v/+/f3//v7+///////+/v7///////v5+v+0f57/fiJX/3YUTP9yDUf/dhVN/30gVf94F0//zqzA///////7+fr/+vf5/////////v////////v5+/+eWoH/cw9J/3cXTv+ELmD/sn2c/8WdtP+CKlz/07TG////////////tICe/5tVff/8+vv///////////+yfZz/cxBJ/3obUv+kZYr/8+zw//////+0gJ7/2b7O////////////4c7Z/3cWTv9xDEb/s36c///////gzNj/fiJX/3cWTv+lZor///////7+/v+fXYP/kEJv/8qluv/k0dz////////////DmbH/dxZO/34iV//hzNj/rHGT/3YUTP+FL2H/7+Xr//////+kZIn/dRJL/30hVv9zD0n/eRpR/8Scs////////f39/5hPef9yDkj/rHOU/409bP9zD0n/rnWW//////+gX4X/dRJL/4AmWv9/I1j/gSdb/30gVv95GVD/49Db///////CmLH/cw9I/44+bP+BKFz/dhRM/8Oasv+1gp//kEJv/30hVv9/I1j/fiJX/34iV/+BJ1v/dRNL/76Rq///////2L3N/3gXT/+BJ1v/gCZa/34hVv+INGX/2sDP/8aetf90EEn/gSdb/34iV/9+Ilf/gSdb/3UTS/++kav//////9i9zf94F0//gSdb/44+bP9zD0j/tYGf///////jz9v/eRlQ/30gVv+BJ1v/gSdb/30gVv95GVD/49Db///////DmLH/cw9I/44+bP+scpT/cg5I/5pTfP/9/P3//////8Scs/95GlH/dRJL/3USS/95GlH/xJyz///////9/f3/mE95/3IOSP+scpT/4czY/34iV/92FE3/wZew////////////5NHc/76Rq/++kav/5NHc////////////wpmx/3cWTv9+Ilf/4czY//////+zfZz/cg1H/30gVv/DmbH/////////////////////////////////w5qy/30hVv9yDUf/s32c////////////+/n7/59bgv9yDUf/dxVN/5hPef/FnLT/2b/O/9m/zv/FnLT/mFB5/3cVTv9yDUf/n1uC//v5+v///////v7+///////7+Pr/tICe/34iV/9yDkj/cg5I/3gXT/94F0//cg5I/3IOR/9+Ilf/tICe//v4+v///////v7+///////+/v7//v39///////j0Nv/rXSV/44+bP+BJ1v/gSdb/44+bP+tdJX/49Db///////+/f3//v7+//////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAAAAAAEAAAEgsAABILAAAAAAAAAAAAAP////////////////////////////////7+/v/9/P3///7////////z7PH/zq3A/6twkv+SRnL/hS9h/38kWP9/JFj/hS9h/5JHcv+qcJL/z6/C//Hp7v/+/f7////////////////////////////////////////////////////////////////////////////+/f7//v39///////q3ub/sXua/4cyY/94GFD/eBdP/3obUv99H1X/fiJX/34iV/99H1X/ehtS/3obUf9yDkj/k0p0//n3+P////////7+///////+/v7//////////////////////////////////////////////////v39///////6+Pn/uYml/30hVv90EUr/fB5U/38kWf9/JFn/fyRY/38kWf+AJVn/fyRY/34iV/+BJ1v/ehxS/4g0ZP/o2eL///////7+/v///v///v3+///+/v/+/f7///////////////////////////////////////38/f//////7eHo/5RLdf9zEEn/fiJX/4AmWv9/I1j/fyRZ/4AlWv9+IVb/ehtS/3cVTf95GlH/gSdb/3kZUP+GMmP/6dvk///////+/f7///7+///////69/n/8eju///////+/f3////////////////////////////9/P3//////+bW3/+FMGH/dxZO/4EnW/9+Ilf/fyNY/4AlWf94GE//dRNL/38lWf+NPGv/n1uC/5VLdv92FE3/hzNk/+nb5P///////fz9///////+/f3//////7J+nP+CK13/5tbg///////9/P3//////////////////v3+///////s4Of/hTBh/3kZUP+BJlr/fiFW/4AlWf97HVP/dhZN/5hQev/Kp7v/697m//7+/v/17/P/j0Bt/4MsXv/q3eX///////38/f///////v7+//////+0gqD/dRNM/3oaUf+FMGH/7ODn///////+/f7////////+////////+/n6/5RKdf93Fk7/gSZa/34hVv+AJlr/dxZO/4g1ZP/Tt8j///////79/v//////8+vw/4c0Zf9+I1f/697l///////9/P3///////79/f//////sn6c/3IOSP+BJ1r/gSZa/3cWTv+USnT/+/n6/////////v///fz9//////+3hqL/dBBK/4EnW/9+IVb/gCZa/3YUTf+aVHz/8+3x///////8+vv///////Lq7/+INmb/gitd/+7j6f//////+/n6//79/v///////v3+///////PrsH/fSFW/30gVv9+I1j/gSdb/3QRSv+3hqL///////38/f//////6drj/30hVv9+Ilf/fiJX/4AlWf93Fk7/mlR8//r4+f//////+/n6///////y6+//jT1r/4EpXP/j0tz/+/n6//v4+v////////////79/f///////v39///////Ttsf/eRpR/38jWP9+I1j/fiJX/30iVv/p2+P///////////+veZj/dRJL/4AmWv9/I1j/ex1T/4g1Zf/x6u7///////z6+///////8urv/5BCb/92E0z/ijdn/4o4Z/+DK17/kURx/7SAnv/s4Of///////38/f///////Pr8//////+5iaX/dRNM/4AlWv+AJlr/dBJL/695mP//////8urv/4cyY/98HlT/fiNY/4AlWf93Fk7/0LDD///////7+fr///////Lr7/+PQm//dxZO/4EnW/98HlT/exxT/3wfVf96GlH/dRJK/34jWP/LqLz///////79/f///v7///////n2+P+OQG3/ehtS/38lWf98HlT/hzJj//Lq7//Nq77/eBlQ/38kWf9/JFn/eRhQ/5ZOeP///////fv8///////y6/D/kENw/3cVTv+BJlr/fiFX/34jV/9/I1j/fiNY/38kWP+BJlr/fSBW/3QRSv/Kprv///////79/f/9/Pz//////8egtv91E0z/gCVa/38kWf94GVD/zau+/6pvkf94F0//fyRZ/4AlWv91E0z/x6G3///////+/v7/8+3x/5FFcP93FU3/gSZa/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/JFn/fSBW/34kWP/r3uX///////38/f//////8Ofs/4MsXv99H1X/gCVZ/3gXT/+qb5H/kkZy/3ocUv9/JFj/fiFW/38kWP/o2uL///////Tt8f+PQm7/dRJL/4EnW/9+IVf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/+BJlr/dRJL/7N+nP///////fz8//7+/v//////m1Z+/3gXT/+AJlr/ehxS/5JGcv+FL2H/fR9V/38kWf96HFL/jDxq//38/P/38vX/jDxq/4EoW/+KOGf/fB5U/34jV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWP96G1H/kURw//7+/v///////fv8//////+we5r/dRNL/4AmWv99H1X/hS9h/38kWP9+Ilf/fyRZ/3cWTv+bVn7/+vf5/4w8av+BKFv/4tHb/4o3Z/97HFP/fyNY/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fyNY/3wfVf+FL2H/9O3x///////8+vv//////7yPqf91Ekv/gCZa/34iV/9/JFj/fyRY/34iV/9/JFj/eRlQ/5dOef+TSHP/fSJW/+7k6v/38vX/gy1f/3wfVf9+I1j/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/I1j/fB9V/4UvYf/07fH///////z6+///////vI+p/3USS/+AJlr/fiJX/38kWP+FL2H/fR9V/34iV/+AJVn/dxZO/4MsXv/q3eX///////z7/P+RRHD/ehtR/38kWP9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWP96G1H/kURw//7+/v///////fv8//////+wepr/dRNL/4AmWv99H1X/hS9h/5JGcv96HFL/fyRZ/3wfVf+ELmD/6Nri///////7+Pr//////7N+nP91Ekv/gSZa/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/gSZa/3USS/+zfpz///////38/P/+/v7//////5tWfv94F0//gCZa/3ocUv+SRnL/qm+R/3gXT/+AJVr/fB9V/4UvYf/x6e3///////78/f//////697l/34kWP99IFb/fyRZ/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWf99IFb/fiRY/+ve5f///////fz9///////w5+z/gyxe/30fVf+AJVn/eBdP/6pvkf/Mq77/eBlQ/38kWf+AJlr/dBJL/8Scs////////fv8//79/f//////yqa7/3QRSv99IFb/gSZa/38kWP9/I1j/fyNY/38kWP+BJlr/fSBW/3QRSv/Kprv///////79/f/9/Pz//////8eht/91E0z/gCVa/38kWf94GVD/zau+//Lq7/+HMmP/fB5U/38lWf96G1L/jj5s//n2+P////////7+//79/f//////y6i8/34jWP91Ekv/ehtR/3wfVf98H1X/ehtR/3USSv9+I1j/y6i8///////+/f3///7+///////69/n/j0Bu/3obUv9/JVn/fB5U/4cyY//y6u///////7B5mP91Ekv/gCZa/4AlWv91E0z/uImk///////8+vv///////38/f//////7ODn/7SAnv+RRHD/hS9h/4UvYf+RRHD/tICe/+zg5////////fz9///////8+vv//////7qLpv91E0v/gCVa/4AmWv91Ekv/sHmY////////////6drj/30hVv9+Ilf/fiNY/38jWP95GlH/07bH///////8+vv//v7+//79/f////////////38/f/07vL/9O7y//38/f////////////79/f/+/v7//Pr7///////VuMn/eRtR/38jWP9/I1j/fiJX/30hVv/p2uP///////38/f//////t4ai/3QRSv+BJ1v/fyNY/30gVf98IFX/1LnJ///////9/P3//fz8//38/f/9/Pz///////////////////////38/P/9/P3//fz8//38/f//////1rrK/30hVv99IFX/fyNY/4EnW/90EUr/t4ai///////9/P3///7////////7+fr/lEp1/3cWTv+AJlr/fyNY/30gVf95GlD/uo2n//r5+v////////////7+/v/9+/z//Pr7//z6+//9+/z//v7+////////////+/n6/7uOqP95GlH/fSBV/38jWP+AJlr/dxZO/5RKdf/7+fr////////+/////////v3+///////s4Of/hTBh/3kZUP+AJlr/fyNY/38jWP91E0v/jkBt/8ikuf/y6+//////////////////////////////////8+vw/8mkuf+PQG3/dRNL/38jWP9/I1j/gCZa/3kZUP+FMGH/7ODn///////+/f7//////////////////fz9///////m1t//hTBh/3cWTv+BJ1v/fiNY/4AlWv96G1L/dRNL/4MsXv+cWH//sXyb/72Pqv+9j6r/sXyb/5xYf/+DLF7/dRNL/3obUv+AJVr/fyNY/4EnW/93Fk7/hTBh/+bW3////////fz9/////////////////////////////fz9///////t4ej/lEt1/3MQSf9+Ilf/gCZa/38lWf+AJVr/fR9V/3gXTv91E0v/dBJL/3QSS/91E0v/eBdO/3wfVf+AJVr/fyVZ/4AmWv9+Ilf/cxBJ/5RLdf/t4ej///////38/f///////////////////////////////////////v39///////6+Pn/uYml/30hVv90EUr/fB5U/38kWf+AJVn/gCZa/4AmWv+AJlr/gCZa/4AmWv+AJlr/gCVZ/38kWf98HlT/dBFK/3whVv+5iaX/+vj5///////+/f3//////////////////////////////////////////////////v3+//79/f//////6t7m/7F7mv+HMmP/eBhQ/3gXT/96G1L/fR9V/34iV/9+Ilf/fR9V/3obUv94F0//eBhQ/4cyY/+we5r/6t7m///////+/f3//v3+/////////////////////////////////////////////////////////////v7+//38/f///v////////Ps8f/OrcD/q3CS/5JGcv+FL2H/fyRY/38kWP+FL2H/kkZy/6twkv/OrcD/8+zx/////////v///fz9//7+/v////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAwAAAAYAAAAAEAIAAAAAAAACQAABILAAASCwAAAAAAAAAAAAD////////////////////////////////////////////////////////////////+/f7//fz9/////////////////+3i6P/NrL//sHua/5pVfP+LO2r/gyxe/38jWP9/I1j/gyxe/4s8av+aVX3/sHua/82twP/t4un///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7///38/f/+/v7///////Ts8f/Horj/nFh//4IqXf94GE//dxZO/3kZUf97HVP/fSBV/34iV/9+Ilf/fSBV/3sdU/95GVH/dxZO/3gZT/+CKl3/nVqB/8Obsv/18PT////////+/v/////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/f3//v39///////w6O3/tIKf/4MsXv90EUr/dxZO/30gVf9/JFn/gCVZ/38kWP9/I1j/fiJX/34iV/9+Ilf/fiJX/38jWP9/JFj/gCVZ/38kWP9/JFn/bgZC/49Eb//28/X////////+/v////////////////////////////////////////////////////////////////////////////////////////////////////////////38/f///////Pv8/8Kasf+CK13/dBJK/30fVf+AJlr/fyRZ/34jV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/4EnW/91E0z/mlV9//n1+P///////v7+///////////////////+///+/f3//////////////////////////////////////////////////////////////////////////////////fz8///////q3uX/l1B5/3MRSv99H1X/gCZa/34jWP9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/gCZa/3UTTP+ZU3v/+PT2///////+/f7//////////////////v7///79/v///////f39///////////////////////////////////////////////////////////////////////9+/z//////9a7y/+AJ1r/dxZO/4EmWv9/I1j/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fyRY/4AlWv+AJVr/fyRY/34jV/99IFb/fiJX/34iV/+BJlv/dRNM/5lTe//49Pb///////79/f/////////////////+/v7///////n19//i0Nv///////79/f////////////////////////////////////////////////////////////38/P//////yqa7/3cYT/98HlX/gCZa/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiNY/4AlWv9/I1j/eRpR/3UTS/91E0v/eBlQ/3ocUv+BKFv/fyRY/4AmWv91E0v/mVN7//j09////////v39//////////////////7+/v/9/f3//////696mf9zEkr/yqe7///////9/Pz//////////////////////////////////////////////////fz8///////Jpbr/dRVM/34iV/9/JFn/fiJX/34iV/9+Ilf/fiJX/34iV/+AJVr/fSBW/3UTS/96HVP/kkdz/7F8mv/LqL3/2cHP/+7l6//FnrX/fSJX/3YUTP+ZU3z/+PT2///////+/f3//////////////////v7+//79/f//////r3qa/3QSSv9/I1j/dhVM/8mluv///////fz8///////////////////////////////////////9/P3//////9W5yf93GE//fiJX/38kWP9+Ilf/fiJX/34iV/9+Ilf/fyRY/38kWf91E0z/gChb/7F8mv/j0tz//f39///////+/f3//////+DN2f+GMWL/cw9J/5lUfP/49Pb///////79/f////////////////////////7///////+vepn/dBFK/4AmWv9/JFj/fiJX/3cYT//Uucn///////38/f////////////////////////////79/v//////6dzj/4AoW/98HlT/fyRZ/34iV/9+Ilf/fiJX/34iV/+AJVn/ex5U/3cYTv+rcpP/7+Xr///////+/v7///////v4+f//////3MbT/38mWf9xDEb/mlV9//j09v///////v39///////////////////+/////////fz9/654l/91E0v/gCVa/34iV/9+Ilf/fyRZ/3weVP+AKFr/6dvj///////+/f7////////////////////////////9/f3/llB4/3cWTv+AJlr/fiJX/34iV/9+Ilf/fiJX/4AmWv95GFD/gy1f/9a9zP///////v7+//38/f/+/f3//Pv8///////dyNX/gClc/3IOSP+aVn7/+PT2///////+/f3///////////////////////79/f//////5tfg/3gcUf98HlT/fyVZ/34iV/9+Ilf/fiJX/4AmWv93Fk7/lk94//39/f///////////////////////fz9///////Alq7/dBFK/4EmWv9+Ilf/fiJX/34iV/9+Ilf/gCZa/3gXT/+OQG3/7eLo///////9+/z//v3+///////9+/z//////97K1v+AJ1v/cApF/5hSev/38vX//v7+//z6+////v/////////////////////////////+/f7//////+LQ2/+BK13/exxT/38kWf9+Ilf/fiJX/34iV/+BJlr/dBFK/8CWr////////fz9///////+/v7//////+7l6/+CK13/fB9V/38jWP9+Ilf/fiJX/34iV/+AJVn/eRlQ/45Abf/y6u////////37/P////////////37/P//////38vX/38nWv92FU3/pWeL//v6+/////////7+/////////////fz9//7+/v///////////////////////v39///////gztn/fiRY/30fVf9/I1j/fiJX/34iV/9+I1j/fR9V/4IrXf/u5ev///////7+/v/9/P3//////7KAnv90Ekv/gCZa/34iV/9+Ilf/fiJX/38kWP98HVT/gy5f/+vf5v///////fz8/////////////fv8///////fzNf/gCda/3kZUf+HM2P/wJau/7yOqf+2haH/xJ20/9zG0//49Pf///////7+/v/+/f3///////////////////////z7/P//////0LHD/3cXTv9/JFn/fiJX/34iV/9+Ilf/gCZa/3QSS/+zgJ7///////38/f//////8uru/4MtX/99H1X/fiNY/34iV/9+Ilf/fiJX/38kWf93GE//07fH///////9+/z////////////9+/z//////+DM2P9/Jln/exxT/4AlWf9+I1j/dhVN/3QQSf91E0v/dBJL/3gYUP+JN2b/t4ej//Pr8P///////fz9///////////////////////9+/z//////653l/91E0z/gCVa/34iV/9+Ilf/fiNY/30fVf+DLV//8urv////////////xqC2/3QRSv+AJlr/fiJX/34iV/9+Ilf/gCVa/3YUTP+qb5H///////38/P////////////37/P//////4c3Z/38nWv97HFP/gCVZ/34iV/9+Ilf/fyRZ/4AmWv+AJVr/gCZa/38kWf97HVP/dBFJ/4UwYf/Vusr///////38/f/////////////////+/v7///////Ls8P+GM2P/ex1T/38jWP9+Ilf/fiJX/4AmWv90EUr/xqC2////////////m1d+/3cWTv9/JFn/fiJX/34iV/9+I1f/fSBW/4AnWv/r3ub///////79/v///////fv8///////hztn/gChb/3scU/+AJVn/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/I1j/gSZa/3sdU/92FU3/x6K4///////9/P3//////////////////fz8///////Alq7/dRNL/4AlWv9+Ilf/fiJX/38kWf93Fk7/nFd+///////r3+b/gipd/30gVf9+I1f/fiJX/34iV/+AJVr/dRNM/613lv///////fz9///////9+/z//////+HP2v+AKFv/exxS/4AlWf9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWf9/I1f/dhZN/9O3yP///////fz9/////////////v7+///////y6u7/hC9g/3wfVP9+I1j/fiJX/34jV/99IFX/gipd/+vf5v/Nq7//eBlP/38kWf9+Ilf/fiJX/34iV/9/I1j/ehxS/9/L1v///////v39//37/P//////4tDa/4ApW/96HFP/gCVZ/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/JFn/ex1T/4UxYf/y6+////////7+/v////////////38/f//////qnCR/3YUTP+AJVn/fiJX/34iV/9/JFn/eBlP/82sv/+wepn/dxZO/4AlWf9+Ilf/fiJX/38kWP96GlH/kERw//z8/P///////Pv8///////i0dv/gSpc/3scUv+AJVn/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/gSZa/3QRSv+2haH///////38/f////////////38/f//////0LHD/3UVTf+AJVn/fiJX/34iV/+AJVn/dxZO/7B6mv+aVHz/eRlR/38kWP9+Ilf/fiJX/4AlWv91E0z/rneX///////7+Pr//////+PR3P+CLF3/eRhQ/4AlWf9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fyNY/3sdVP+JNmb/+PT2///////+/v7///////79/v//////69/m/38lWf9+IVb/fiNX/34iV/9/JFj/eRlR/5pUfP+LO2n/ex1T/38jWP9+Ilf/fiJX/4AlWf91E0v/yKS5////////////5NLc/4MuX/91E0z/hzNj/34jWP9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWf94GFD/3MXS///////9/P3////////+/v//////+vj5/4w8av97HFL/fyNY/34iV/9/I1j/ex1T/4s8af+DLF7/fSBV/34iV/9+Ilf/fiJX/38kWf93GE//2L/O///////j0Nv/hTBh/3AIRP+kZYn/wJau/3YVTf9/JFn/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/4AmWv90Ekv/xJ20///////9+/z//////////////v///////5dQef94GFD/fyRZ/34iV/9+Ilf/fSBV/4MsX/9/I1j/fiJX/34iV/9+Ilf/fiJX/38iV/95HVL/6dvj/+rd5f+DL2D/cQxG/5hSev//////uYql/3QRSv+AJlr/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/4AlWv91Ekv/t4ik///////9+/z////////////+/f7//////59cg/93Fk7/gCVZ/34iV/9+Ilf/fiJX/38jWP9/I1j/fiJX/34iV/9+Ilf/fiJX/30gVv+AJ1v/zq3B/4s6aP9wCkT/m1Z+//Xw8///////toai/3USS/+AJVr/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/4AmWv91Ekv/t4ik///////9+/z////////////+/f7//////55cg/93Fk7/gCVZ/34iV/9+Ilf/fiJX/38jWP+DLF7/fSBV/34iV/9+Ilf/fiJX/34hVv9/JFn/gCdb/3IOSP+aVX3/9/T2//38/f//////xJ2z/3QSS/+AJlr/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/4AmWv90Ekv/xJ2z///////9+/z//////////////v///////5dQef94GFD/fyRZ/34iV/9+Ilf/fSBV/4MsXv+LO2n/ex1T/38jWP9+Ilf/fiJX/34iV/9/JFj/dBFK/5pUfP/49Pb///////z6+///////3MTS/3gYUP9/JFn/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWf94GFD/3MTS///////9/P3////////+/v//////+vj5/4s8af97HFL/fyNY/34iV/9/I1j/ex1T/4s8af+aVHz/eRlR/38kWP9+Ilf/fiJX/38kWP96G1H/nFh///fz9v///////v39///+/v//////+PT2/4k3Zv97HVP/fyNY/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fyNY/3sdU/+JN2b/+PT2///////+/v7///////79/v//////69/m/38lWf9+IVb/fiNX/34iV/9/JFj/eRlR/5pUfP+wepn/dxZO/4AlWf9+Ilf/fiJX/4AlWf91FEz/zay////////8+/z////////////9/P3//////7aFof90EUr/gSZb/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/gSZb/3QRSv+2haH///////38/f////////////38/f//////0LHD/3UVTf+AJVn/fiJX/34iV/+AJVn/dxZO/7B6mf/Nq7//eBhP/38kWf9+Ilf/fiJX/4AlWf92FE3/p2uO///////9/P3////////////+/v7///////Lr7/+FMWH/ex1T/38kWf9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/JFn/ex1T/4UxYf/y6+////////7+/v////////////38/f//////qnCR/3YUTP+AJVn/fiJX/34iV/9/JFn/eBhP/82rv//r3+b/gSpc/30gVf9+I1f/fiJX/34jWP98H1X/gy1f//Do7f///////v7+/////////////fz9///////Ut8j/dhZN/38iV/9/JFn/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/38kWf9/Ilf/dhZN/9S3yP///////fz9/////////////v7+///////y6+//hTBh/3weVP9+I1j/fiJX/34jV/99IFX/gipc/+vf5v//////m1d+/3cWTv9/JFn/fiJX/34iV/+AJVr/dRNL/7+TrP///////fv8//////////////////38/f//////x6K4/3YVTf97HVP/gSZb/38jWP9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9/I1j/gSZa/3sdU/92FU3/x6K4///////9/P3//////////////////fz8///////Bl6//dRNL/4AlWv9+Ilf/fiJX/38kWf93Fk7/m1d+////////////xp+2/3QRSv+AJlr/fiJX/34iV/9/I1j/fB5U/4YyYv/y6u////////7+/v/////////////////9/P3//////9W6yv+FMWH/dBFK/3sdU/9/JFn/gCZa/4AmWv+AJlr/gCZa/38kWf97HVP/dBFJ/4UwYf/Vusr///////38/f/////////////////+/v7///////Pt8f+HNGT/ex1T/38jWP9+Ilf/fiJX/4AmWv90EUr/xqC2////////////8uru/4MsXv99H1X/fiNY/34iV/9+Ilf/gCZa/3UTTP+tdpb///////37/P///////////////////////fz9///////z6/D/uIej/4k3Zv94GFD/dBJL/3USS/91Ekv/dBJL/3gYUP+JN2b/t4ej//Pr8P///////fz9///////////////////////9+/z//////696mf91E0z/gCZa/34iV/9+Ilf/fiNY/30fVf+DLF7/8uru///////9/P3//////7OAnf90Ekv/gCZa/34iV/9+Ilf/fiJX/38kWf93F07/0LHD///////8+/z///////////////////////79/f/+/v7///////j09//cxtP/xJ2z/7iIpP+3iKT/xJ2z/93F0//49Pf///////7+/v/+/f3///////////////////////z7/P//////0rXG/3cYT/9/JFj/fiJX/34iV/9+Ilf/gCZa/3QSS/+zgJ3///////38/f/+/v7//////+7l6/+CK13/fB9V/38jWP9+Ilf/fiJX/38jWP98H1X/fiVY/+HP2v///////Pv8///////////////////////+/v7//fz9/////////////////////////////////////////////fz9//7+/v///////////////////////Pv8///////j0dv/fyda/3wfVf9/I1j/fiJX/34iV/9/I1j/fB9V/4IrXf/u5ev///////7+/v///////fz9///////Alq7/dBFK/4EmWv9+Ilf/fiJX/34iV/9/JFn/exxS/4IsXv/i0Nv///////37/P/+/v7////////////////////////+/v/9/P3//fv8//37/P/9+/z//fv8//38/f///v7///////////////////////7+/v/9+/z//////+TS3f+DLl//exxS/38lWf9+Ilf/fiJX/34iV/+BJlr/dBFK/8CWrv///////fz9///////////////////////9/f3/llB4/3cWTv+AJlr/fiJX/34iV/9+Ilf/gCVZ/3scUv9+JVj/07bH///////+/f7//fz8//7+/v/////////////////////////////////////////////////////////////////+/v7//fz8//79/v//////1LjJ/38mWf97HFL/gCVZ/34iV/9+Ilf/fiJX/4AmWv93Fk7/llB4//39/f////////////////////////////79/v//////6dvj/4AoW/98HlT/fyRZ/34iV/9+Ilf/fiJX/38kWf98H1X/dxdO/696mf/08PP////////+/v/9/P3//fz9//79/v///v/////////////////////////+///+/f7//fz9//38/f/+/v7///////Xw8/+wfJr/dxdO/3wfVf9/JVn/fiJX/34iV/9+Ilf/fyRZ/3weVP+AKFr/6dvj///////+/f7////////////////////////////9/P3//////9W5yf93GE//fiJX/38kWP9+Ilf/fiJX/34iV/9/I1j/fyRZ/3UTS/+GM2P/wpmx//Tu8v////////7///////////////7+//79/v/+/f7///7+//////////////7////////17/L/w5qy/4c0Y/91E0v/fyRY/38jWP9+Ilf/fiJX/34iV/9/JFj/fiJX/3cYT//Vucn///////38/f///////////////////////////////////////fz8///////Jpbr/dRVM/34iV/9/JFn/fiJX/34iV/9+Ilf/fiJX/4AmWv97HVP/dBJL/4QwYP+rcZP/0rTF/+zh6P/7+fr///////////////////////v5+v/s4ej/0rTF/6tyk/+FMGH/dBJL/3sdU/+AJlr/fiJX/34iV/9+Ilf/fiJX/38kWf9+Ilf/dRVM/8mluv///////fz8//////////////////////////////////////////////////38/P//////yaa7/3cYT/98HlX/gCZa/34iV/9+Ilf/fiJX/34iV/9/I1j/gCZa/3weVP91E0z/dRVM/38lWf+MPGr/l1B5/59cg/+fXIP/l1B5/4w8av9/JVn/dRVM/3UTTP98HlT/gCZa/38jWP9+Ilf/fiJX/34iV/9+Ilf/gCZa/3weVf93GE//yqa7///////9/Pz////////////////////////////////////////////////////////////9+/z//////9a7y/+AJ1r/dxZO/4EnWv9/I1j/fiJX/34iV/9+Ilf/fiJX/38jWP+AJVn/gCVZ/34hVv97HFL/eBhP/3cWTv93Fk7/eBhP/3scUv9+IVb/gCVZ/4AlWf9/I1j/fiJX/34iV/9+Ilf/fiJX/38jWP+BJlr/dxZO/4AnWv/Wu8v///////37/P///////////////////////////////////////////////////////////////////////fz8///////q3uX/l1B5/3MRSv99H1X/gCZa/34jWP9+Ilf/fiJX/34iV/9+Ilf/fiJX/34jV/9/I1j/fyRZ/4AlWf+AJVn/fyRZ/38jWP9+I1f/fiJX/34iV/9+Ilf/fiJX/34iV/9+I1j/gCZa/3wfVf90EUr/l1B5/+re5f///////fz8//////////////////////////////////////////////////////////////////////////////////38/f///////Pv8/8Kasf+CK13/dBJK/30fVf+AJlr/fyRZ/34jV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+Ilf/fiJX/34iV/9+I1f/fyRZ/4AmWv99H1X/dBJK/4ErXf/CmrH//Pv8///////9/P3////////////////////////////////////////////////////////////////////////////////////////////+/f3//v39///////w6O3/tIKf/4MsXv90EUr/dxZO/30gVf9/JFn/gCVZ/38kWP9/I1j/fiJX/34iV/9+Ilf/fiJX/38jWP9/JFj/gCVZ/38kWf99IFX/dxZO/3QRSv+DLF7/tIKf//Do7f///////v39//79/f////////////////////////////////////////////////////////////////////////////////////////////////////////7///38/f/+/v7///////Ts8f/Horj/nFh//4IqXf94GE//dxZO/3kZUf97HVP/fSBV/34iV/9+Ilf/fSBV/3sdU/95GVH/dxZO/3gYT/+CKl3/nFh//8eiuP/z7PH///////7+/v/9/P3///7////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/f7//fz9/////////////////+3i6P/NrL//sHua/5pVfP+LO2r/gyxe/38jWP9/I1j/gyxe/4s7av+aVXz/sHua/82sv//s4uj//////////////////fz9//79/v////////////////////////////////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
$HeroImage = "C:\Temp\favicon.ico"
[byte[]]$Bytes = [convert]::FromBase64String($Picture_Base64)
[System.IO.File]::WriteAllBytes($HeroImage,$Bytes)
# Picture Base64 end

$SourceFilePath = "https://qpulse.surrey.ac.uk/QPulse"
$ShortcutPath = "C:\Users\Public\Desktop\Q-Pulse Web.lnk"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $SourceFilePath
$shortcut.IconLocation = "C:\Temp\favicon.ico"
$shortcut.Save()