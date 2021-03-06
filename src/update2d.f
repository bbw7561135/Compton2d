c     This subroutines solves the Fokker-Planck
c      equation for the electrons and updates
c          electron spectral parameters
c
c
c
      subroutine update
      implicit none
      include 'mpif.h'
      include 'general.pa'
      include 'commonblock.f'
c

      double precision temp_min, temp_max


      parameter (temp_min = 5.d0)
      parameter (temp_max = 1.d3)

c
c
c   rad_cp = parameter limiting the minimum time step 
c            to ensure efficient radiative coupling
c            between zones. rad_cp = 3.33d-11 corresponds
c            to (Delta t)_min = (Delta R)/c for 1. zone
c
c   df_implicit = maximum relative temperature change for
c                 implicit Fokker-Planck time step
c
c
c    Tmin = minimum electron temperature [keV]
c    temp_max = maximum electron temperature [keV]
c
c    df_T = Maximum allowed relative temperature
c           increment/decrement per time step
c
c
c     variables used only in update2d and its subroutines.
      integer i, j, k, l, fp_steps, i_nt, zone
      double precision t_fp, n_p
      double precision Te_old(jmax, kmax)
      double precision sum_dt, Delta_T, sum_min
      double precision Th_p, Th_e, g_av, gamma_bar, gamma_R
      double precision h_T, dT_coulp, y, volume, d_t, df_time
      double precision dT_sy, dT_c, dT_br, dT_A, dT_total(jmax,kmax)
      double precision E_el, E_pos, ne, ne_new, n_positron, n_lept
      double precision gamma(num_nt), Delta_g
      double precision f_old(num_nt), npos_old(num_nt)
      double precision f_new(num_nt), npos_new(num_nt)
      double precision a_i(num_nt), b_i(num_nt), c_i(num_nt)
      double precision f_th, hr_th_Coul, hr_th_c, hr_th_sy
      double precision hr_th_br, hr_th_A, Omega, Om_p, v_a2, v_a, t_A
      double precision rhoh_wp, nu_A, k_min, k_max, vth_p, vth_e
      double precision te_mo, hr_th_total, sum_g11, sum_g_1
      double precision hr_nt_mo, hr_nt_C, hr_nt_br, hr_nt_sy
      double precision hr_nt_Coul, hr_nt_A, hr_st_A, heating_nt
      double precision hrmo_old, f_br, f_sy, fdisp_A, fdg_A
      double precision g_thr, Th_K2, McDonald, g_read, grid_temp
      double precision dg_cp(num_nt), disp_cp(num_nt)
      double precision dg_ce(num_nt), disp_ce(num_nt)
      double precision beta, The_mo, dg_sy(num_nt), dg_br(num_nt)
      double precision dg_ic(num_nt), dgcp_old, Intdgcp, dg_mo
      double precision p_g, k_res, om_R, Gamma_k, tau_k, xx
      double precision disp_mo, dg_A(num_nt), Intd2cp
      double precision disp_A(num_nt), fcorr_turb, dgA_original
      double precision dte_mo, hr_max, heat_total, rho, q_nm
      double precision D_g2, dgdt(num_nt), disp(num_nt)
      double precision sum_E_old, sum_E_new, sum_p, sum_old
      double precision pp_rate, pa_rate
      double precision dfmax, sum_E, Delta_ne, Delta_np
      double precision d_temp, gbar, curv, curv_old, curv_2
      double precision sum_nt, sum_th, sump_old, dg2, p_1
      double precision sum_g, sumg_old, N_nt, f_pl, l_fraction
      double precision dE_fraction, dt_min, temp0, temp1
      double precision The_new
      double precision rmid, zmid, tl_flare, tlev, Tp_flare
      double precision fcorr_coul, f_disp_corr
c

c     variables common from outside modified by update.
c     gbar_nth and N_nth are not modified or used in update, but
c     are in the same common block as the others which are modified.
c     tea(jmax, kmax) also probably belongs here.

c     MPI variables
      integer status(MPI_STATUS_SIZE), num_sent, end_signal, sender,
     1        num_zones
      double precision ans
c
c
c     variables in trid are shared between FP_calc, tridag and trid_p in one 
c     step
      common / trid_update / a_i, b_i, c_i, f_old, f_new, npos_old,
     1                npos_new
c     Below are libraries from the subroutne coulomb.


c
c
c        Output formats
c
  5   format('Evolution of thermal population in zone ',i2,
     1       ',',i2,':')
 10   format ('   Coulomb heating/cooling rate: ',e14.7,' erg/s')
 15   format ('       Synchrotron cooling rate: ',e14.7,' erg/s')
 20   format ('           Compton cooling rate: ',e14.7,' erg/s')
 25   format ('    Bremsstrahlung cooling rate: ',e14.7,' erg/s')
 30   format ('Hydromagnetic acceleration rate: ',e14.7,' erg/s')
 35   format ('     Total heating/cooling rate: ',e14.7,' keV/s')
 45   format('Te_new(',i2,',',i2,') = ',e14.7,' keV')
 50   format(' Adjusted time step: ',e14.7,' s')
 70   format ('Te = ',e14.7,'; file name: ',a20)
 75   format ('Tp = ',e14.7,'; file name: ',a20)
 95   format (' Acceleration rate of suprathermal particles: ',
     1        e14.7,' erg/s.')
 1000 format ('     Total heat input (Coulomb + hydromagn.): ',
     1        e14.7,' erg/s.')
 1020 format ('Total energy (old): ',e14.7,
     1        ' ergs; (new): ',e14.7,' ergs.')
 1025 format ('(Delta E)/E = ',e14.7)
 1035 format ('  dT_max = ',e14.7)
 1040 format('           dt_new = ',e14.7,' s')
 1045 format('current time step = ',e14.7,' s')
 1050 format('New time step = ',e14.7,' s')
c
c
c     MPI Initialization 
c      call MPI_INIT(ierr)
      call MPI_COMM_RANK(MPI_COMM_WORLD, myid, ierr)
      call MPI_COMM_SIZE(MPI_COMM_WORLD, numprocs, ierr)
      num_sent = 0
      end_signal = jmax*kmax+1
      if(ncycle.lt.2) then
         call make_FP_bcast_type
      endif
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      if(myid.eq.master) then
c     Fraction of photon time step to be used
c       as elementary implicit FP time step
c
      f_t_implicit = 2.d-1
      lnL = 20.d0
      dT_max = 0.d0
c
      do 110 j = 1, nz
         do 100 k = 1, nr
            Te_new(j,k) = tea(j,k)
            Te_old(j,k) = tea(j,k)
 100     continue
 110  continue
c
      write(*,*) 'myid=', myid, ' before cens_add_up'
      call cens_add_up
      write(*,*) 'myid=', myid, ' after cens_add_up'
c
c
      if (ncycle.gt.1) goto 160
c     The initial time step lets the simulation volume fill
c     up with photons, then resets the timer to zero.
c
c     Only the master nodes does the initial time
c     step calculation.  JF, 2 Feb. 2005
      call photon_fill
c   After the first time step, start "update" here.
c
  160 continue
c
c
c
c     Solve Fokker-Planck equation for thermal + nonthermal
c            particle population (MB, 20/July/2001)
c
      hr_st_total = 0.d0
      hr_total = 0.d0
      E_tot_old = 0.d0 
      E_tot_new = 0.d0
c
c
c
c
c     Broadcast data to all the processes needed in the
c     Fokker-Planck routine.
      write(*,*) 'myid=',myid,' b4 fp_bcast dt1=',dt(1),' t0=',t0(2)
      call FP_bcast
      write(*,*) 'myid=',myid,' af fp_bcast dt1=',dt(1),' t0=',t0(2)
      num_zones = nr*nz
c
c     This sends the first round of zones to the slaves for processing.
      do 900 l = 1, min(num_zones, (numprocs-1))
         zone = l   
         call FP_send_job(l, zone)
      write(*,*) 'myid=',myid, ' sending zone=', zone
         num_sent = num_sent + 1
  900 continue
c
c     As slaves complete processing a zone, this recieves the results
c     and sends the next zone to the slaves.
      do 902 l = 1, num_zones
         write(*,*) 'myid=', myid, ' recieve result'
            call FP_recv_result(sender, zone)
          write(*,*) 'myid=', myid, ' recieves zone=', zone, 
     1           ' from node=', sender
          if(num_sent.lt.num_zones) then
               zone = num_sent+1
               call FP_send_job(sender, zone)
               num_sent = num_sent + 1
            else
               write(*,*) 'myid=', myid, ' sending end signal'
               call FP_send_end_signal(sender)
               write(*,*) 'myid=', myid, ' end signal sent to node=', 
     1              sender
            endif
 902  continue
c
      write(*,*) 'myid=',myid,' b4 old,new=',E_tot_old, E_tot_new
      call E_add_up
      write(*,*) 'myid=',myid,' af E_add_up'
      write(4, *)
      write(4, *)
      write(4,1000) hr_total
      write(4,95) hr_st_total
      dE_fraction = (E_tot_new - E_tot_old)/E_tot_old
      write(4, *) 'Energy Check:'
      write(4, 1020) E_tot_old, E_tot_new
      write(*,*) 'myid=',myid,' old, new:  ',E_tot_old, E_tot_new
      write(4, 1025) dE_fraction
      write(4, *)
c
 910  continue

      write(4, 1035) dT_max
      if (dT_max.lt.(0.2*df_T)) then ! Xuhui
         dt_new = 3.d0*dt(1)
      else if (dT_max.lt.(.75*df_T)) then
         dt_new = 1.1d0*dt(1)
      else if (dT_max.gt.(5.*df_T)) then ! Xuhui
         dt_new = 0.33d0*dt(1)
      else if (dT_max.gt.(1.25*df_T)) then
         dt_new = 7.5d-1*dt(1)
      else
         dt_new = dt(1)
      endif

      write(4,1040) dt_new
      dt(2) = dt(1)
      write(4,1045) dt(1)
c      if (dabs(dE_fraction).lt.1.d-2) then
c         dt(1) = dmin1((1.1d0*dt(1)), dt_new)
c      else if (dabs(dE_fraction).gt.2.d-2) then
c         dt(1) = dmin1((7.5d-1*dt(1)), dt_new)
c      endif ! Xuhui del 5/11/09
c
c      Set dt_min so that efficient radiative coupling
c         between adjacent zones is guaranteed
c
      dt_min = rad_cp*dmin1(dr, dz)

c
c      dt(1) = dmax1(dt(1), dt_min) !Xuhui ori
      write(4,1050) dt(1)
      write(4,*)
      write(4,*)
c
c     store results for next MC time step
      do 930 j = 1, nz
         do 920 k = 1, nr     
            if (tna(j,k).gt.1.) then
               tea(j,k) = Te_new(j,k)
               temp0 = temp_min
               temp1 = temp_max
               tea(j,k) = dmin1(temp1, tea(j,k))
               tea(j,k) = dmax1(temp0, tea(j,k))
            endif
 920     continue
 930  continue
      call FP_end_bcast  ! Xuhui
c
c
c     end master part
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      else if(myid.ne.master) then
c     beginning of slave part
c
      lnL = 20.d0
      write(*,*) 'myid=',myid,' b4 cens_add_up'
      call cens_add_up
      write(*,*) 'myid=',myid,' af cens_add_up'
c
      hr_st_total = 0.d0
      hr_total = 0.d0
      E_tot_old = 0.d0 
      E_tot_new = 0.d0
c
c     recieve broadcast of parameters used in FP_calc.
      write(*,*) 'myid=',myid,' b4 fp_bcast dt1=',dt(1),' t0=',t0(2)
      call FP_bcast
      write(*,*) 'myid=',myid,' af fp_bcast dt1=',dt(1),' t0=',t0(2)
c
      num_zones = nr*nz
c
c     if there are more nodes than work skip this node.
      if(myid.gt.num_zones) goto 990
c
c     as long as the node doesn't recieve the end_signal, it
c     will keep performing the FP calcuation for zones.
 991  call FP_recv_job(zone)
      call get_j_k(zone, j, k, nr)
      write(*,*) 'myid=',myid, ' recieved, zone=', zone, ' j=',j,' k=',k
      if(zone.eq.end_signal) goto 990
      call FP_calc(zone)
      write(*,*) 'myid=', myid, ' zone=', zone, ' done with fp_calc'
      call FP_send_result(zone)
      goto 991
 990  continue
c
      write(*,*) 'myid=',myid,' b4 old,new=',E_tot_old, E_tot_new
      call E_add_up
      write(*,*) 'myid=',myid,' af E_add_up'
      write(*,*) 'myid=',myid,' old, new:  ',E_tot_old, E_tot_new
      call FP_end_bcast  ! Xuhui 4/5/09
      endif
c     end of slave part
c
c
 950  return
      end
c
c
c
c
c========================================================================================
c========================================================================================
c     This performs the Fokker-Planck calculation.
c     Based on Change & Cooper (1970).
c     Xuhui Chen, 2009
      subroutine FP_calc(zone)
      implicit none
      include 'general.pa'
      include 'commonblock.f'
      
      integer zone
c
      double precision temp_min, temp_max
      parameter (temp_min = 5.d0)
      parameter (temp_max = 1.d3)
c
      logical ex
c
c     variables used only in FP_calc
      integer i, j, k, fp_steps,ii
      integer dgr_p, dgr_e, dge_cycle, dte_stop, temp_i, i_ph
      integer i_nt
      integer i_100000, i_10000, i_1000, i_100, i_10, i_1,i_5,id_10,id_1
C~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      integer nunit_fnt
      double precision sum_gg
      double precision n_inject, inject_ne(num_nt)
     1       ,inj_dur
     1       ,inj_y,inj_sum, inj_E,inj_rho
     1       ,t_esc, t_acc
     1       ,inj_rate, inj_g2var ! Xuhui inj
      double precision D_gminus,D_gplus,smw(num_nt)
     1                 ,bigW(num_nt),bigB,bigC(num_nt) ! Xuhui FP
      character *10  dateup, timeup
c~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      double precision t_fp
      double precision Delta_T
      double precision Th_p, Th_e, g_av, gamma_bar, gamma_R
      double precision h_T, y, volume, d_t, d_dT_At
      double precision E_el, E_pos, ne, ne_new, n_positron, n_lept
      double precision gamma(num_nt), Delta_g
      double precision f_old(num_nt), npos_old(num_nt)
      double precision f_new(num_nt), npos_new(num_nt)
      double precision a_i(num_nt), b_i(num_nt), c_i(num_nt)
      double precision f_th, hr_th_Coul, hr_th_c, hr_th_sy
      double precision hr_th_br, hr_th_A, Omega, Om_p, v_a2, v_a, t_A
      double precision rhoh_wp, nu_A, k_min, k_max, vth_p, vth_e
      double precision te_mo, hr_th_total, sum_g11, sum_g_1
      double precision hr_nt_mo, hr_nt_C, hr_nt_br, hr_nt_sy
      double precision hr_nt_Coul, hr_nt_A, hr_st_A, heating_nt
      double precision hrmo_old, f_br, f_sy, fdisp_A, fdg_A
      double precision g_thr, Th_K2, McDonald, g_read, grid_temp
      double precision dg_cp(num_nt), disp_cp(num_nt)
      double precision dg_ce(num_nt), disp_ce(num_nt)
      double precision beta, The_mo, dg_sy(num_nt), dg_br(num_nt)

      double precision dg_ic(num_nt), dgcp_old, Intdgcp, dg_mo
      double precision p_g, k_res, om_R, Gamma_k, tau_k, xx
      double precision disp_mo, dg_A(num_nt), Intd2cp
      double precision disp_A(num_nt), fcorr_turb, dgA_original
      double precision dte_mo, hr_max, heat_total, rho, q_nm
      double precision D_g2, dgdt(num_nt), disp(num_nt)
      double precision sum_E_old, sum_E_new, sum_p, sum_old
      double precision pp_rate, pa_rate
      double precision dfmax, sum_E, Delta_ne, Delta_np
      double precision d_temp, gbar, curv, curv_old, curv_2
      double precision sum_nt, sum_th, dg2, p_1
      double precision sum_g, sumg_old, N_nt, f_pl, l_fraction
      double precision The_new
      double precision rmid, zmid, tl_flare, tlev, Tp_flare
      double precision fcorr_coul, f_disp_corr
      double precision n_p
      double precision dT_total(jmax,kmax)
c
c     variables common from outside update used within update and fp_calc.
c     the above Asurfs are not used in fp_calc but are in the common
c     block with z, r etc.
c     Below are libraries from the subroutine coulomb.
c
c     variables common between FP_calc, update, and photon_fill
c     variables common between update and FP_calc.
      double precision dg_icold
c
      character *30 name_dge, name_dgp, fntname, dgdtfile, dispfile
c 
      common / trid_update / a_i, b_i, c_i, f_old, f_new, npos_old,
     1                npos_new
c     Below are libraries from the subroutine coulomb.
c     d_update has variables that are common between photon_fill, FP_calc, 
c     and update.
c     to_fp_calc has variables common between fp_calc and update
c____________________________________________________________________
c
      data name_dge/'rates/p01_dge0005.dat'/ ! Xuhui
      data name_dgp/'rates/p01_dgp0005.dat'/
c
 10   format ('   Coulomb heating/cooling rate: ',e14.7,' erg/s')
 15   format ('       Synchrotron cooling rate: ',e14.7,' erg/s')
 20   format ('           Compton cooling rate: ',e14.7,' erg/s')
 25   format ('    Bremsstrahlung cooling rate: ',e14.7,' erg/s')
 30   format ('Hydromagnetic acceleration rate: ',e14.7,' erg/s')
 40   format ('   Moeller heating/cooling rate: ',e14.7,
     1        ' erg/s (kT_e = ',e14.7,' keV)')
 55   format(e14.7,1x,e14.7)
 60   format ('Thermal temperature estimate: ',e14.7,' keV')
 65   format(e14.7,1x,e14.7,1x,e14.7)
 80   format(e12.5, 1x, e12.5, 1x, e12.5, 1x, e12.5, 1x,
     1       e12.5, 1x, e12.5, 1x, e12.5, 1x, e12.5)
 85   format(e12.5, 1x, e12.5, 1x, e12.5, 1x, e12.5, 1x, e12.5)
 90   format ('   Total heating/cooling rate (FP electrons): ',
     1        e14.7,' erg/s.')
 95   format (' Acceleration rate of suprathermal particles: ',
     1        e14.7,' erg/s.')
 1000 format ('     Total heat input (Coulomb + hydromagn.): ',
     1        e14.7,' erg/s.')
 1005 format('FP electron temperature in zone ',i2,
     1       ',',i2,': ',e11.4,' keV (',e11.4,')')
 1010 format ('Pair fraction: ',e14.7)
 1015 format ('PP-rate: ',e14.7,' cm^(-3)/s; PA-rate: ',
     1         e14.7,' cm^(-3)/s')
 1030 format('delta^2 = ',e14.7,'; l_wp/l_Coul = ',e14.7)
c
c
c
      call get_j_k(zone, j, k, nr)
      write(*,*) 'zone=', zone, ' E_tot_new=', E_tot_new, ' j,k=',j,k
      write(*,*) 'zone=', zone, ' ecens=',ecens(j,k)
c
            t_esc = r_esc*z(nz)/c_light ! Xuhui escape
            t_acc = r_acc*z(nz)/c_light ! Xuhui acceleration
            t_fp = 0.d0
            fp_steps = 0
            Te_new(j,k) = tea(j,k)
c           if (tna(j,k).lt.1.d0) return ! Xuhui ?
c
c
c         Retrieve particle distribution
c
            volume = vol(j,k)
            E_el = 0.d0
            E_pos = 0.d0
            n_p = n_e(j,k)  ! proton density
            ne = n_p*(1. +f_pair(j,k)) ! electron density
            ne_new = ne
            n_positron = n_p*f_pair(j,k) ! positron density
            n_lept = ne + n_positron ! lepton density
            if (n_lept.lt.1.d-11) return ! Xuhui 11/20/08
            if(f_pair(j,k).gt.1.d-1)write(*,*)'f_pair=',f_pair(j,k)
            if(j.eq.1.and.k.eq.1)write(*,*)'n_e =',ne
c
            do 180 i = 1, num_nt
               gamma(i) = gnt(i) + 1.d0
               if (i.gt.1) then
                  Delta_g = gnt(i) - gnt(i-1)
                  if (pair_switch.eq.1) then
                     n_positron = n_positron + Delta_g*n_pos(j,k,i)
                     E_pos = E_pos + Delta_g*gamma(i)*n_pos(j,k,i)
                  endif
                  E_el = E_el + Delta_g*gamma(i)*f_nt(j, k, i)
               endif
  180       continue
            write(*,*)'gamma=',gamma(1),'gnt=',gnt(1)
c
            E_el = E_el*ne*8.176d-7*volume
            if (pair_switch.eq.1) E_pos = E_pos*8.176d-7*volume
            E_tot_old = E_tot_old + E_el + E_pos + ec_old(j, k)
            E_tot_new = E_tot_new + ecens(j, k)
c
            sum_p = 0.
            do 185 i = 1, num_nt-1
  185       sum_p = sum_p + (gnt(i+1) - gnt(i))*f_nt(j, k, i)
c
            do 190 i = 1, num_nt
               if (pair_switch.eq.1) npos_old(i) = n_pos(j, k, i)
               f_nt(j, k, i) = f_nt(j, k, i)/sum_p
               f_old(i) = f_nt(j, k, i)
  190       continue
            f_old(num_nt) = 0.d0
            if (pair_switch.eq.1) then
               npos_old(num_nt) = 0.d0
            endif
c
c            if ((ncycle.eq.2).and.(j.eq.1).and.(k.eq.1)) then
c               open(21, file='f_old.dat', status='unknown')
c               do 195 i = 1, num_nt
c  195          write(21, 55) gnt(i), f_old(i)
c               close(21)
c            endif
c
c         Calculate pair annihilation rates
c
          if (pair_switch.eq.1) call pa_calc(j, k, n_e)
c
c
c         Calculate energy loss, acceleration, 
c                and dispersion rates
c                  (MB, 20/July/2001)
c
c            Th_p = tna(j,k)/5.382d5
c
            if (k.gt.1) then
               rmid = 5.d-1*(r(k) + r(k-1))
            else
               rmid = 5.d-1*(r(k) + rmin)
            endif
            if (j.gt.1) then
               zmid = 5.d-1*(z(j) + z(j-1))
            else
               zmid = 5.d-1*(z(j) + zmin)
            endif
c
            if (cf_sentinel.eq.1) then
               y = 5.d-1*(((rmid - r_flare)/sigma_r)**2.d0
     1                  + ((zmid - z_flare)/sigma_z)**2.d0
     2                  + ((time - t_flare)/sigma_t)**2.d0)
c
               if (y.lt.1.d2) then
                  tl_flare = flare_amp/dexp(y)
               else
                  tl_flare = 0.d0
               endif
            else
               tl_flare = 0.d0
            endif
c
            tlev = turb_lev(j,k) + tl_flare
            Tp_flare = tna(j,k)*(1.d0 + tl_flare)
c
            Th_p = Tp_flare/9.382d5
            Th_e = tea(j,k)/5.11d2
            f_th = 1.5d0*volume*n_lept
c
c             Thermal cooling rates in erg/s
c
            hr_th_br = -Eloss_br(j,k)/dt(1)
c            hr_th_c = edep(j,k)/dt(1)
           do i=1,num_nt-1
              dg_ic(i) = 0.d0
              do i_ph = 1, nphfield
                    dg_ic(i) = dg_ic(i) 
     1                       - n_field(i_ph, j, k)*F_IC(i, i_ph)/volume
              enddo
           enddo  ! Xuhui 3/9/11
c
c
  200       g_av = gamma_bar(Th_e)

            hr_th_c =0.d0
            do i=1,num_nt-1
               hr_th_c = hr_th_c - 8.176d-7*dg_ic(i)*
     1             f_old(i)*(gnt(i+1)-gnt(i))*volume*n_lept
            enddo    ! Xuhui 3/9/11

            if(fp_steps.gt.1000000) then 
               write(*,*) 'zone=',zone, 
     1              ' fp_steps=', fp_steps, ' t_fp=', 
     2              t_fp, ' dt(1)=', dt(1)
               write(*,*) ' d_t=',d_t, ' f_th=',f_th,
     1              ' hr_th_total=',hr_th_total
               write(*,*) 'Te_new=',Te_new(j,k),
     1              ' df_implicit=',df_implicit
               write(*,*) 'hr_th_Coul=',hr_th_Coul
               write(*,*) 'hr_th_sy=',hr_th_sy
               write(*,*) 'hr_th_br=',hr_th_br
               write(*,*) 'hr_th_C=',hr_th_C
               write(*,*) 'hr_th_A=',hr_th_A
               stop
            endif
            gamma_R = 2.1d-3*sqrt(n_lept)/(B_field(j,k)*sqrt(g_av))
c
            h_T = .79788*(2.*((Th_e + Th_p)**2.d0) + 2.d0*(Th_e + Th_p) 
     1             + 1.d0)/(((Th_e + Th_p)**1.5d0)*(1.d0 + 1.875d0*Th_e 
     2             + .8203d0*(Th_e**2.d0)))
            hr_th_Coul = f_th*1.7386d-26*n_p*lnL*h_T
     1                  *(Tp_flare - Te_new(j,k))
c
            y = gamma_R/g_av
            if (y.lt.100.d0) then
c              hr_th_sy = -(Eloss_cy(j,k) + Eloss_sy(j,k) 
c     1                     + Eloss_th(j,k))/(dt(1)*dexp(y))
            hr_th_sy = -Eloss_sy(j,k)/(dt(1)*dexp(y))
            else
               hr_th_sy = 0.d0
            endif
c
            Omega = 1.76d7*B_field(j,k)
            Om_p = Omega/1.836d3
            v_a2 = 4.765d22*(B_field(j,k)**2.d0)/ne
            if (v_a2.gt.9.d20) v_a2 = 9.d20
            v_a = dsqrt(v_a2)
c
            if (k.eq.1) then
               dr = r(k) - rmin
            else
               dr = r(k) - r(k-1)
            endif
            if (j.eq.1) then
               dz = z(j) - zmin
            else
               dz = z(j) - z(j-1)
            endif
            t_A = dmin1(dr, dz)/v_a
c
c            if (ft_turb(j,k).gt.1.d-20) then
c               rhoh_wp = ft_turb(j,k)*hr_th_Coul/volume
c            else
c               rhoh_wp = turb_lev(j,k)*hr_th_Coul/volume
c            endif
c
            hr_th_A = tlev*hr_th_Coul
            if (hr_th_A.lt.1.d-20) hr_th_A = 1.d-20
            nu_A = .5d0*(q_turb(j,k) + 3.d0)
            k_min = 2.d0*pi/dmin1(dr, dz)
            k_max = Omega/dsqrt(v_a2)
            vth_p = c_light*dsqrt(3.*Th_p + 2.25d0*(Th_p**2.d0))
     1             /(1.d0 + 1.5d0*Th_p)
            vth_e = c_light*dsqrt(3.*Th_e + 2.25d0*(Th_e**2.d0))
     1             /(1.d0 + 1.5d0*Th_e)
            if (vth_p.gt.c_light) vth_p = c_light
            if (vth_e.gt.c_light) vth_e = c_light
c
c
c            hr_th_total = hr_th_Coul + hr_th_sy + hr_th_br + hr_th_c
c     1                  + hr_th_A
            hr_th_total = hr_th_sy + hr_th_c + hr_th_A ! Xuhui

c
c          Determine estimated (thermal) electron temperature
c      after current time step for implicit Moeller FP coefficients
c
            dT_total(j,k) = 6.25d8*dt(1)*hr_th_total/f_th
            f_t_implicit = df_implicit*Te_new(j,k)
     1                    /dabs(dT_total(j,k))
            if (f_t_implicit.gt.df_T) f_t_implicit = df_T
            te_mo = Te_new(j,k) + f_t_implicit*dT_total(j,k)
c
            if (te_mo.lt.temp_min) then
               te_mo = temp_min
            else if (te_mo.gt.temp_max) then
               te_mo = temp_max
            endif
c
            sum_g11 = 0.d0
            do 210 i = 1, num_nt-1
  210       sum_g11 = sum_g11 + (gamma(i)**1.1d0)*f_old(i)
     1                         *(gnt(i+1) - gnt(i))
c
            sum_g_1 = 0.d0
            do 220 i=1, num_nt-1
  220       sum_g_1 = sum_g_1 + (gamma(i)**2.d0 - 1.d0)*f_old(i)
     1                         *(gnt(i+1) - gnt(i))
c
c
c
c            Create file names for Coulomb and Moeller  
c                energy loss and dispersion rates     
c
             hr_nt_mo = 1.d80
             dge_cycle = 0
             dte_stop = 0
c
             dgr_p = 0
 230         dgr_e = 0
             The_mo = 1.9569d-3*te_mo
             dge_cycle = dge_cycle + 1
             temp_i = 0
             grid_temp = 0.d0
 240         temp_i = temp_i + 1
             grid_temp = grid_temp + 1.d0
             if (dabs(te_mo - grid_temp).le.5.d-1) then
                i_1000 = temp_i/1000
                name_dge(14:14) = char(48+i_1000)
                i_100 = (temp_i - 1000*i_1000)/100
                name_dge(15:15) = char(48+i_100)
                i_10 = (temp_i - 1000*i_1000 - 100*i_100)/10
                name_dge(16:16) = char(48+i_10)
                i_1 = temp_i - 1000*i_1000 - 100*i_100 - 10*i_10
                name_dge(17:17) = char(48+i_1) ! Xuhui
                id_10 = myid/10
                name_dge(8:8) = char(48+id_10)
                id_1 = myid-id_10
                name_dge(9:9) = char(48+id_1)
c
             endif
c
             if ((te_mo.ge.(grid_temp + 5.d-1))) goto 240 
c
             grid_temp = 0.d0
             temp_i = 0
 245         temp_i = temp_i + 1
             grid_temp = grid_temp + 1.d1
c
         if ((dgr_p.eq.0).and.
     1            (dabs(Tp_flare - grid_temp).le.5.d0)) then
         i_5 = temp_i/100000
         if (i_5.gt.0) then
            name_dgp(12:12) = char(48+i_5)
         else
            name_dgp(12:12) = 'g'
         endif
         i_100000 = (temp_i - 100000*i_5)/10000
         if((i_100000).gt.0.or.(i_5.gt.0)) then
            name_dgp(13:13) = char(48+i_100000)
         else
            name_dgp(13:13) = 'p'
         endif
         i_10000 = (temp_i - 100000*i_5 - 10000*i_100000)/1000
         name_dgp(14:14) = char(48+i_10000)
         i_1000 = (temp_i - 100000*i_5 - 10000*i_100000 -
     1        1000*i_10000)/100
         name_dgp(15:15) = char(48+i_1000)
         i_100 = (temp_i - 100000*i_5 - 10000*i_100000
     1        - 1000*i_10000 - 100*i_1000)/10
         name_dgp(16:16) = char(48+i_100)
         i_10 = temp_i -100000*i_5 - 10000*i_100000 - 1000*i_10000 -
     1        100*i_1000 - 10*i_100
         name_dgp(17:17) = char(48+i_10)  ! Xuhui
         id_10 = myid/10
         name_dgp(8:8) = char(48+id_10)
         id_1 = myid-id_10
         name_dgp(9:9) = char(48+id_1)
c     Below is the old way of getting name_dgp.  Changed to above.
c     J. Finke 20 June 2006
c             if ((dgr_p.eq.0).and.
c     1           (dabs(Tp_flare - grid_temp).le.5.d0)) then
c                i_5 = temp_i/10000
c                if (i_5.gt.0) name_dgp(9:9) = char(48+i_5)
c                i_10000 = (temp_i - 10000*i_5)/1000
c                name_dgp(10:10) = char(48+i_10000)
c                i_1000 = (temp_i - 10000*i_5 
c     1                 - 1000*i_10000)/100
c                name_dgp(11:11) = char(48+i_1000)
c                i_100 = (temp_i - 10000*i_5 - 1000*i_10000 
c     1                - 100*i_1000)/10
c                name_dgp(12:12) = char(48+i_100)
c                i_10 = temp_i - 10000*i_5 - 1000*i_10000 
c     1               - 100*i_1000 - 10*i_100
c                name_dgp(13:13) = char(48+i_10)
c
c                write(n3, 75) Tp_flare, name_dgp
c            if((j.eq.1).and.(k.eq.1)) write(*,*) 'name_dgp:  ', name_dgp
c
             endif
c          
             if (Tp_flare.ge.(grid_temp + 5.d0)) goto 245 
c
c          Inquire if energy loss / dispersion rate files exist;
c                   if files exist, attempt to read
c                   (check for electron energy grid)
c

            inquire(file=name_dge, EXIST=ex)
            if (ex) then
               open(unit=17, file=name_dge, status='unknown')
               do 250 i = 1, num_nt
                  read(17, 65) g_read, dg_ce(i), disp_ce(i)
                  if ((gamma(i).gt.1.002).and.
     1                (dabs((g_read - gamma(i))/gamma(i)).gt.1.d-2))
     2            then
                      close(17)
                   goto 260
                  endif  
                  dg_ce(i) = dg_ce(i)*n_lept
                  disp_ce(i) = disp_ce(i)*n_lept
 250          continue
               dgr_e = 1
               close(17)
c
            endif
c
 260        continue
c
            inquire(file=name_dgp, EXIST=ex)
            if (ex) then
               open(unit=17, file=name_dgp, status='unknown')
               do 270 i = 1, num_nt
                  read(17, 65) g_read, dg_cp(i), disp_cp(i)
                  if ((gamma(i).gt.1.002).and.
     1                (dabs((g_read - gamma(i))/gamma(i)).gt.1.d-2))
     2            then
                      close(17)
                      goto 280
                  endif
                  dg_cp(i) = dg_cp(i)*n_p
                  disp_cp(i) = disp_cp(i)*n_p
 270           continue
               dgr_p = 1
               close(17)
c
            endif
c
 280        continue
c
            if (k.gt.1) then
               rmid = 5.d-1*(r(k) + r(k-1))
            else
               rmid = 5.d-1*(r(k) + rmin)
            endif
            if (j.gt.1) then
               zmid = 5.d-1*(z(j) + z(j-1))
            else
               zmid = 5.d-1*(z(j) + zmin)
            endif
c
            if (cf_sentinel.eq.1) then
               y = 5.d-1*(((rmid - r_flare)/sigma_r)**2.d0
     1                  + ((zmid - z_flare)/sigma_z)**2.d0
     2                  + ((time - t_flare)/sigma_t)**2.d0)
c
               if (y.lt.1.d2) then
                  tl_flare = flare_amp/dexp(y)
               else
                  tl_flare = 0.d0
               endif
            else
               tl_flare = 0.d0
            endif
c
            tlev = turb_lev(j,k) + tl_flare
            fdg_A = pi*(q_turb(j,k) - 1.d0)*(Omega**(2.d0 
     1             - q_turb(j,k)))
     2           *(k_min**(q_turb(j,k) - 1.d0))*tlev*v_a2
     3           *(c_light**(q_turb(j,k) - 3.d0))/q_turb(j,k)
            fdisp_A = 2.d0*pi*(q_turb(j,k) - 1.d0)*(Omega**(2.d0 
     1                - q_turb(j,k)))*(k_min**(q_turb(j,k) - 1.d0))
     2               *tlev*v_a2*(C_light**(q_turb(j,k) - 3.d0))
     3               /(q_turb(j,k)*(q_turb(j,k) + 2.d0))
c            f_sy = (Eloss_sy(j,k) + Eloss_cy(j,k) + Eloss_th(j,k))
c     1             /(8.176d-7*volume*dt(1)*n_lept*sum_g_1)
c            f_sy = Eloss_sy(j,k)/(8.176d-7*volume*dt(1)*n_lept*sum_g_1)
            f_sy = 1.058d-15*B_field(j,k)**2/8.176d-7 ! Xuhui 2/18/11
c
            f_br = Eloss_br(j,k)
     1            /(8.176d-7*volume*dt(1)*n_lept*sum_g11)
c
c
            hrmo_old = dabs(hr_nt_mo)
            heating_nt = 0.d0
            hr_st_A = 0.d0
            hr_nt_A = 0.d0
            hr_nt_C = 0.d0
            hr_nt_sy = 0.d0
            hr_nt_Coul = 0.d0
            hr_nt_br = 0.d0
            hr_nt_mo = 0.d0
            g_thr = 1.d0 + 4.d0*Th_e
            Th_K2 = The_mo*McDonald(2.d0, (1.d0/The_mo))
c
            do 300 i = 1, num_nt
               beta = dsqrt(1.d0 - 1.d0/(gamma(i)**2.d0))
               y = gamma_R/gamma(i)
               if (y.lt.100.d0) then
                  dg_sy(i) = -f_sy*(gamma(i)**2.d0 - 1.d0)/dexp(y)
               else
                  dg_sy(i) = -1.d-50
               endif
c
               dg_br(i) = -f_br*(gamma(i)**1.1d0)
c
c               dg_ic(i) = 0.d0
c               do 290 i_ph = 1, nphfield
c                  dg_ic(i) = dg_ic(i) 
c     1                     - n_field(i_ph, j, k)*F_IC(i, i_ph)/volume
c
c 290           continue ! Xuhui moved to before the start of the FP loop 3/9/11
c
               if (dgr_p.eq.0) then
                  if (gamma(i).lt.3.) then
                     dg_cp(i) = 1.194d-14*n_p*lnL
     1                   *Intdgcp(gamma(i), beta, Tp_flare)
     2                  /((1. + 1.875d0*Th_p + .8203d0*(Th_p**2.d0))
     3                   *sqrt(Th_p)*(gamma(i)**2.d0)*beta)
                  else
                     dg_cp(i) = dgcp_old
                  endif
               endif
c
               dgcp_old = dg_cp(i)
c
               if (dgr_e.eq.0) then
                  dg_ce(i) = 1.496d-14*lnL*(n_lept/Th_K2)
     1                      *dg_mo(gamma(i), beta, The_mo)
     2                      /(gamma(i)*gamma(i)*beta)
               endif
c
c
c         Account for Landau damping by reducing the
c          according to the average of the absorbed
c           wave energy through the current region
c                    (MB, 22/Sept/2000)
c
               p_g = gamma(i)*beta
               k_res = Omega/(c_light*p_g)
               om_R = k_res*v_a
c
               if ((k_res.lt.k_min).or.(k_res.gt.k_max)) then
                  tau_k = 1.d30
               else
                  y = om_R - 2.d0*Om_p
                  if (dabs(y).lt.1.d-20) then
                     Gamma_k = 1.d50
                  else
                     Gamma_k = 1.77245d0*Om_p*((Om_p - om_R)**2.d0)
     1                        /(om_R - 2.d0*Om_p)
                  endif
                  y = ((om_R - Omega)/(k_res*vth_e))**2.d0
                  if (y.lt.2.d2) then
                     xx = 1.836d3/(dexp(y)*k_res*vth_e)
                  else
                     xx = 0.d0
                  endif
                  y = ((om_R - Om_p)/(k_res*vth_p))**2.d0
                  if (y.lt.2.d2)
     1               xx = xx + 1.d0/(dexp(y)*k_res*vth_p)
                  Gamma_k = Gamma_k*xx
                  tau_k = Gamma_k*t_A
c
               endif
               if (tau_k.lt.1.d-6) then
                  dg_A(i) = fdg_A*(p_g**(q_turb(j,k) - 1.d0))
               else if (tau_k.lt.2.d2) then
                  dg_A(i) = fdg_A*(p_g**(q_turb(j,k) - 1.d0))
     1                     *(1.d0 - dexp(-tau_k))/tau_k
               else
                  dg_A(i) = fdg_A*(p_g**(q_turb(j,k) - 1.d0))/tau_k
               endif
c
               if (i.lt.num_nt) then
                  hr_nt_Coul = hr_nt_Coul + dg_cp(i)*f_nt(j, k, i)
     1                                     *(gnt(i+1) - gnt(i))
                  hr_nt_A = hr_nt_A + dg_A(i)*f_nt(j, k, i)
     1                                     *(gnt(i+1) - gnt(i))
               endif
c
               if (dgr_e.eq.0) then
c                   if (gamma(i).lt.1.d3) then
c                   if (gamma(i).lt.1.d6) then ! Xuhui 10/30/08
                      f_disp_corr = 2.5d-1
                      disp_ce(i) = f_disp_corr*2.99d-14*lnL
     1                            *(n_lept/Th_K2)
     1                            *disp_mo(gamma(i), beta, The_mo)
     2                            /(gamma(i)*gamma(i)*beta)
c                   else
c                      disp_ce(i) = 0.
c                   endif
               endif
c
               if (dgr_p.eq.0) then
                  if (gamma(i).lt.3.) then
                     disp_cp(i) = 1.194d-14*n_p
     1                   *Intd2cp(gamma(i), beta, Tp_flare)
     2                   /((Th_p**1.5d0)*(1.d0 + 1.875d0*Th_p 
     3                    + .8203d0*(Th_p**2.d0))*(gamma(i)**2.d0)*beta)
                  else
                     disp_cp(i) = 0.d0
                  endif
               endif
c
               if (tau_k.lt.1.d-6) then
                  disp_A(i) = fdisp_A*(gamma(i)**q_turb(j,k))
     1                       *(beta**(q_turb(j,k) + 1.d0))
               else if (tau_k.lt.2.d2) then
                  disp_A(i) = fdisp_A*(gamma(i)**q_turb(j,k))
     1                       *(beta**(q_turb(j,k) + 1.d0))
     2                       *(1.d0 - dexp(-tau_k))/tau_k
               else       
                  disp_A(i) = fdisp_A*(gamma(i)**q_turb(j,k))
     1                    *(beta**(q_turb(j,k) + 1.d0))/tau_k
               endif
c
  300       continue
c
c
            if (dgr_e.eq.0) then
               open(unit=17, file=name_dge, status='unknown')
               do 310 i = 1, num_nt
  310          write(17, 65) gamma(i), (dg_ce(i)/n_lept), 
     1                        (disp_ce(i)/n_lept)
               g_read = 0.d0
               write(17, 65) g_read, g_read, g_read
               close(17)
            endif
c
            if (dgr_p.eq.0) then
               open(unit=17, file=name_dgp, status='unknown')
               do 320 i = 1, num_nt
 320           write(17, 65) gamma(i), (dg_cp(i)/n_p), (disp_cp(i)/n_p)
               g_read = 0.d0
               write(17, 65) g_read, g_read, g_read
               close(17)
            endif
c
            do 330 i = 1, num_nt
 330        if (gamma(i).gt.9.d0) goto 340
c
 340        p_g = dsqrt(gamma(i)**2.d0 - 1.d0)
            dgA_original = fdg_A*(p_g**(q_turb(j,k) - 1.d0))
            fcorr_turb = dgA_original/dg_A(i)
            hr_nt_A = 0.d0
c
            hr_nt_Coul = hr_nt_Coul*8.176d-7*n_lept*volume
            fcorr_coul = hr_th_Coul/hr_nt_Coul
            hr_nt_Coul = hr_th_Coul
            do 350 i = 1, num_nt
               dg_A(i) = gamma(i)**1/t_acc
               disp_A(i) = gamma(i)**2/t_acc/2.d0
c               dg_A(i) = dg_A(i)*fcorr_turb
c               disp_A(i) = disp_A(i)*fcorr_turb
               dg_cp(i) = dg_cp(i)*fcorr_coul
c
c               disp(i) = disp_ce(i) + disp_cp(i) + disp_A(i)
c               dgdt(i) = dg_sy(i) + dg_br(i) + dg_ic(i) + dg_cp(i) 
c     1                 + dg_ce(i) + dg_A(i)
c               disp(i) = disp_ce(i) + disp_A(i) !Xuhui
c               dgdt(i) = dg_sy(i) + dg_br(i) + dg_ic(i) 
c     1                 + dg_ce(i) + dg_A(i) ! Xuhui 10/27/08 take out protons
               disp(i) = disp_A(i) !Xuhui
               dgdt(i) = dg_sy(i) + dg_ic(i) + dg_A(i) ! Xuhui 6/11/08 deactivate sth.

c
               if (i.lt.num_nt) then
                  heating_nt = heating_nt + dgdt(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  hr_nt_sy = hr_nt_sy + dg_sy(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  hr_nt_br = hr_nt_br + dg_br(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  hr_nt_C = hr_nt_C + dg_ic(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  hr_nt_mo = hr_nt_mo + dg_ce(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  hr_nt_A = hr_nt_A + dg_A(i)*f_old(i)
     1                                     *(gamma(i+1) - gamma(i))
                  if (gamma(i).gt.g_thr) 
     1                hr_st_A = hr_st_A + dg_A(i)*f_old(i)
     2                                   *(gamma(i+1) - gamma(i))
               endif
 350        continue
c
            heating_nt = heating_nt*8.176d-7*n_lept*volume
            hr_nt_mo = hr_nt_mo*8.176d-7*n_lept*volume
            hr_st_A = hr_st_A*8.176d-7*n_lept*volume
            hr_nt_A = hr_nt_A*8.176d-7*n_lept*volume
            hr_nt_C = hr_nt_C*8.176d-7*n_lept*volume
            hr_nt_sy = hr_nt_sy*8.176d-7*n_lept*volume
            hr_nt_br = hr_nt_br*8.176d-7*n_lept*volume
c
            heat_total = hr_nt_Coul + hr_nt_A
            l_fraction = hr_nt_A/hr_nt_Coul
c
            hr_max = dmax1(dabs(hr_nt_Coul), dabs(hr_nt_sy))
            hr_max = dmax1(hr_max, dabs(hr_nt_C))
            hr_max = dmax1(hr_max, dabs(hr_nt_br))
            hr_max = dmax1(hr_max, dabs(hr_nt_A))
            if (dte_stop.eq.1) goto 360
c
            if (dabs(hr_nt_mo).gt.(1.d-1*hr_max)) then
               if (dabs(hr_nt_mo).gt.hrmo_old) then
                  te_mo = te_mo - dte_mo
                  dte_stop = 1
                  goto 230
               endif
               if (hr_nt_mo.gt.0.d0) then
                  dte_mo = -1.d0
               else
                  dte_mo = 1.d0
               endif
               te_mo = te_mo + dte_mo
               if ((te_mo.gt.temp_max).or.(te_mo.lt.temp_min).
     1             or.(dge_cycle.gt.50)) goto 360
               goto 230
            endif
c
 360        E_tot_old = E_tot_old + heat_total*f_t_implicit*dt(1)
c
            if (fp_steps.eq.0) then
               hr_total = hr_total + heat_total
               hr_st_total = hr_st_total + hr_st_A
            else
               goto 380
            endif
c
           if(myid.eq.1)then
            dgdtfile='rates/dgdt000.dat'
            dispfile='rates/disp000.dat'
            dgdtfile(11:11) = char(48 + int(ncycle/100))
            dgdtfile(12:12) = char(48 + int(ncycle/10)-
     1                 10*int(ncycle/100))
            dgdtfile(13:13) = char(48 + ncycle-
     1                 10*int(ncycle/10))
            dispfile(11:11) = char(48 + int(ncycle/100))
            dispfile(12:12) = char(48 + int(ncycle/10)-
     1                 10*int(ncycle/100))
            dispfile(13:13) = char(48 + ncycle-
     1                 10*int(ncycle/10))

            open(unit=24, file=dgdtfile, status='unknown')
            open(unit=25, file=dispfile, status='unknown')
            
            do 370 i = 1, num_nt
               write(24, 80) gnt(i), dg_sy(i), dg_br(i), dg_ic(i), 
     1                       dg_cp(i), dg_ce(i), dg_A(i), dgdt(i)
               write(25, 85) gnt(i), disp_ce(i), disp_cp(i), 
     1                       disp_A(i), disp(i)
 370        continue
            close(24)
            close(25)
           endif
c
  380       continue
            d_t = f_t_implicit*dt(1)
c
c           make the FP time step stops right at the end of the MC time step.
c           Xuhui 3/10/10
            if(d_t.gt.(dt(1)-t_fp))d_t=1.00001d0*(dt(1)-t_fp)
c
  390       continue
c
c Solve the Fokker-Planck Equation
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c===================================================================
c           Implicit version of the
c       scheme of Nayakshin & Melia (1998)
c       **********************************
c       used the method in Chang and Cooper(1970) instead of N&M98
c
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c           If pairs are present, 
c      re-normalize positron distribution
c
            if (pair_switch.eq.0) then
               f_pair(j,k) = 0.d0
               n_positron = 0.d0
               goto 465
            endif
c
            n_positron = f_pair(j,k)*n_p
            if (n_positron.gt.1.d-20) then
               sum_p = 0.d0
               do 430 i = 1, num_nt-1
 430           sum_p = sum_p + npos_new(i)*(gamma(i+1) - gamma(i))
c
               sum_p = sum_p/n_positron  ! normalize npos back to particle density
               if (sum_p.gt.1.d-20) then
                  do 440 i = 1, num_nt
                     npos_new(i) = npos_new(i)/sum_p
 440              continue
               endif
            endif
c
c
c         Add pair production and annihilation
c
 450        ne_new = ne
            pp_rate = 0.d0
            pa_rate = 0.d0
            n_positron = 0.d0
            do 460 i = 1, num_nt-1
              Delta_ne = (dn_pp(j,k,i) + dne_pa(j,k,i))*d_t
              Delta_np = (dn_pp(j,k,i) + dnp_pa(j,k,i))*d_t
c
              f_old(i) = f_old(i) + Delta_ne/ne
              npos_new(i) = npos_new(i) + Delta_np
              pp_rate = pp_rate +
     1                  dn_pp(j,k,i)*(gamma(i+1) - gamma(i))
              pa_rate = pa_rate +
     1                  dnp_pa(j,k,i)*(gamma(i+1) - gamma(i))
c
              if (f_old(i).lt.1.d-50) f_old(i) = 0.d0
              if (npos_new(i).lt.1.d-50) npos_new(i) = 0.d0
c

              if ((Delta_ne.gt.ne).or.(Delta_np.gt.ne)) then
                 write(*,*) 'j = ',j
                 write(*,*) 'gamma = ',gamma(i)
                 write(*,*) 'Delta_ne = ',Delta_ne
                 write(*,*) 'Delta_np = ',Delta_np
                 write(*,*) 'dne_pp = ',dn_pp(j,k,i)
                 write(*,*) 'dne_pa = ',dne_pa(j,k,i)
                 write(*,*) 'dnp_pa = ',dnp_pa(j,k,i)
              endif
              n_positron = n_positron 
     1                   + npos_new(i)*(gamma(i+1) - gamma(i))
 460        continue
            if (n_positron.lt.1.d-50) n_positron = 0.d0
 465        ne_new = n_p + n_positron
            ne = ne_new
            f_pair(j,k) = dmax1(0.d0, (n_positron/n_p))

           
c____________________________________________________________________
c         Electron injection 
           n_inject = 0.d0
c----------------------------------------------------------------------
c         constant electron pick up at medium energy
          if(pick_sw.eq.1)then
           inj_sum = 0.d0
           inj_E = 0.d0
           do i=1, num_nt-1
              inject_ne(i) = 1.d2*dexp(-(gamma(i)-inj_gg)**2/
     1                 2/inj_sigma**2)/(inj_sigma*dsqrt(2*pi))
                      inj_sum = inj_sum + inject_ne(i)*(gnt(i+1)-gnt(i))
                    inj_E = inj_E + inject_ne(i)*(gnt(i+1)-gnt(i))*
     1                   gamma(i)
           enddo
           inj_rho = pick_rate*d_t
           do i = 1, num_nt-1
                inject_ne(i) = inj_rho*inject_ne(i)/inj_sum
                f_old(i) = f_old(i) + inject_ne(i)/ne
                n_inject = n_inject + inject_ne(i)*(gnt(i+1)-gnt(i))
           enddo
          endif
c----------------------------------------------------------------------
c         Injection by a shock! Xuhui inj 11/17/08
         if(inj_switch .ne. 0) then
           inj_sum = 0.d0
           inj_E = 0.d0
           if((time+t_fp-inj_t).gt.dz/inj_v*(j-1)
     1        .and.(time+t_fp-inj_t).lt.dz/inj_v*j
     1        .and.k.le.nr)then ! small region injection
                  do i = 1, num_nt-1
c          determine the electron distribution      ccccccccccccccccccccc
                    if(inj_dis.eq.1) then
c          inject electrons of a Gaussian distribution
                     inject_ne(i) = 1.d2*dexp(-(gamma(i)-inj_gg)**2/
     1                    2/inj_sigma**2)/(inj_sigma*dsqrt(2*pi))
                    else if(inj_dis.eq.2) then
c          inject electrons of a Power-law distribution
                      inj_g2var = inj_g2*10**
     1                     ((time+t_fp-inj_t)*inj_v/z(nz))
                      if(gamma(i).gt.inj_g1)then
                          if(g2var_switch.eq.1)then
                            inj_y = gamma(i)/inj_g2var
                          else
                            inj_y = gamma(i)/inj_g2
                          endif
                          if(inj_y.lt.1.d2)then
                      inject_ne(i) =1.d2/((gamma(i)**inj_p)*dexp(inj_y))
                          else
                             inject_ne(i) = 0.d0
                          endif
                      else
                          inject_ne(i) = 0.d0
                      endif
c          c        c       c       c       c        ccccccccccccccccccccc
                    endif
                      inj_sum = inj_sum + inject_ne(i)*(gnt(i+1)-gnt(i))
                    inj_E = inj_E + inject_ne(i)*(gnt(i+1)-gnt(i))*
     1                   gamma(i)
                  enddo
               inj_E = inj_E/inj_sum
               !inj_rate = inj_L/8.186d-7/inj_E/(r(nr)**2*dz)
               inj_rate = inj_L/8.186d-7/inj_E/(pi*r(nr)**2*dz)
               inj_rho = inj_rate*d_t
               write(*,*)'injection rate:(cm^-3*s^-1)',inj_rate
                  do i = 1, num_nt-1
                    inject_ne(i) = inj_rho*inject_ne(i)/inj_sum
                    f_old(i) = f_old(i) + inject_ne(i)/ne
                    n_inject = n_inject + inject_ne(i)*(gnt(i+1)-gnt(i))
                  enddo
                  inj_E= inj_E*8.186d-7*(pi*r(nr)**2*dz)*inj_rho/d_t
                  write(*,*)'injected L (erg/s) = ',inj_E

           endif

c          The t_esc/(t_esc+d_t) term is caused by particle escape.
c          This is calculated when using N^j+1 instead N^j with t_escape
         endif
           ne_new = ne + n_inject
           ne = ne_new          ! electron density increases
           n_p = n_p + n_inject !  protons are also injected
           n_e(j,k) = n_p
           n_lept = n_lept+n_inject ! total lepton density increases
c___________________________________________________________________
c          Particle escape
           ne_new = ne_new*t_esc/(t_esc+d_t)
           ne = ne_new
           n_p = n_p*t_esc/(t_esc+d_t)
           n_e(j,k) = n_p
           n_lept = n_lept*t_esc/(t_esc+d_t)


c          Calculate the coefficients
c
c
            a_i(1) = 0.d0
            b_i(1) = 1.d0
            c_i(1) = 0.d0
            a_i(num_nt) = 0.d0
            b_i(num_nt) = 1.d0
            c_i(num_nt) = 0.d0
c            do 410 i = 2, num_nt-1
c               Delta_g = (gnt(i+1) - gnt(i-1))
c               D_g2 = (gnt(i+1) - gnt(i-1))
c     1               *(gnt(i+1) - gnt(i))
c
c               q_nm = gnt(i+1)/gnt(i)
c
c               alpha = 2.d0/(1. + q_nm)
c               rho = 2.d0*q_nm/(1. + q_nm)
c               if (i.eq.3) rho = q_nm
c
c               if (i.eq.num_nt-1) then
c                  c_i(i) = 0.d0
c               else 
c                  c_i(i) = d_t*(dgdt(i+1)/Delta_g - disp(i+1)/D_g2)
c               endif
c
c               if (i.eq.2) then
c                  b_i(i) = 1.d0 + d_t*(dgdt(i)/Delta_g
c     1                               + disp(i)/(alpha*D_g2))
c               else if (i.eq.num_nt-1) then
c                  b_i(i) = 1.d0 - d_t*(dgdt(i)/Delta_g
c     1                           - rho*disp(i)/(alpha*D_g2))
c               else
c                  b_i(i) = 1.d0 + 2.d0*d_t*disp(i)/(alpha*D_g2)
c               endif
c
c               if (i.eq.2) then
c                  a_i(i) = 0.d0
c               else
c                  a_i(i) = -d_t*(dgdt(i-1)/Delta_g 
c     1                      + rho*disp(i-1)/(alpha*D_g2))
c               endif


c  410       continue

c'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
            do 475 i = 2, num_nt-1
               D_gminus = gnt(i) - gnt(i-1)
               D_gplus = gnt(i+1) - gnt(i)
               Delta_g = sqrt(gnt(i)/gnt(i-1))*D_gminus
               
               if(i.eq.2)then
                  bigB = -(dgdt(1)+dgdt(2)) !+(disp(2)-disp(1))/D_gminus/2.d0
                  bigC(1) = (disp(1)+disp(2))/2.d0 !/4.d0
                  smw(1) = D_gminus*bigB/bigC(1)
                  bigW(1) = smw(1)/(exp(smw(1))-1.d0)
               endif

               bigB = -(dgdt(i)+dgdt(i+1))/2.d0 !+(disp(i+1)-disp(i))
!     1                /2.d0/D_gplus  ! Xuhui 4/24/11
               bigC(i) = (disp(i)+disp(i+1))/2.d0 !/4.d0
               smw(i) = D_gplus*bigB/bigC(i)
               bigW(i) = smw(i)/(exp(smw(i))-1.d0)
c
               c_i(i) = -d_t*(bigC(i)*smw(i)/
     1                     (1.d0-exp(-smw(i)))/Delta_g/D_gplus)

                b_i(i) = 1.d0 + d_t/Delta_g*(bigC(i)*bigW(i)/
     1                    D_gplus+bigC(i-1)*smw(i-1)/
     1                    (1.d0-exp(-smw(i-1)))/D_gminus)+d_t/t_esc

               a_i(i) = -d_t/Delta_g*bigC(i-1)*bigW(i-1)/D_gminus

  475       continue  ! Xuhui
c''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
c
c

c         Now, solve the tridiagonal matrix of the 
c       implicitly discretized Fokker-Planck equation
c
            call tridag
            if (pair_switch.eq.1) call trid_p
c
            f_new(num_nt) = 0.d0
            if (pair_switch.eq.1) then
               npos_new(num_nt) = 0.d0
               npos_new(1) = 0.d0
            endif
            f_new(1) = 0.d0
c
c==================================================================
c


            dfmax = 0.
            sum_p = 0.
            sum_E = 0.
            do 480 i = 1, num_nt-1
               sum_p = sum_p + (gnt(i+1) - gnt(i))*f_new(i)
               sum_E = sum_E + (gnt(i+1) - gnt(i))*gamma(i)*f_new(i)
               Pnt(j, k, i) = sum_p
 480        continue
            sum_E = sum_E/sum_p ! Xuhui inj
            sum_old = sum_p
c
c
c            Advance in time
c
            t_fp = t_fp + d_t
            fp_steps = fp_steps + 1
c
            do 485 i = 1, num_nt
               f_new(i) = f_new(i)/sum_p
               f_old(i) = f_new(i)
               if (pair_switch.eq.1) npos_old(i) = npos_new(i)
 485        continue
c
c
c_____________________________________________________________________
c            Determine new electron temperature
c
c
             gbar = 0.d0
             do 490 i = 1, num_nt-1
                gbar = gbar + gamma(i)*f_new(i)*(gnt(i+1) - gnt(i))
 490         continue
c
             The_new = Th_e
             d_temp = .005*Th_e
             if(gbar.gt.g_av)then
                do 500, while(gbar.gt.g_av)
c                   The_new = The_new + d_temp
                   The_new = The_new*1.005 ! Xuhui
                   g_av = gamma_bar(The_new)
c                   if (The_new.gt.1.5) goto 520 ! Xuhui 10/30/08
 500            continue
             else
                do 510, while(gbar.lt.g_av)
c                  The_new = The_new - d_temp
                  The_new = The_new/1.005 ! Xuhui
                  g_av = gamma_bar(The_new)
                  if (The_new.lt.1.d-2) write(*,*)'The_new < 0.01' ! Xuhui test
                  if (The_new.lt.1.d-2) goto 520
 510            continue
             endif
             
c
 520        continue
c            if (The_new.gt.1.5d0) The_new = 1.5d0 ! Xuhui 10/30/08
            Te_new(j,k) = 5.11d2*The_new
            Th_e = The_new
c_______________________________________________________________________
c
c            Next time step
c
            if (t_fp.lt.dt(1)) goto 200
            write(*,*)'myid=',myid,'fp_steps=',fp_steps
            write(*,*)'tea=',Te_new(j,k)
c
c
c
c      Normalize new electron and positron distributions
c
            E_el = 0.d0
            E_pos = 0.d0
            do 540 i = 1, num_nt
               f_nt(j, k, i) = f_new(i)
               if (pair_switch.eq.1) n_pos(j,k,i) = npos_new(i)
               Pnt(j, k, i) = Pnt(j, k, i)/sum_p
               if (i.gt.1) then
                  E_el = E_el + f_nt(j, k, i)*gamma(i)
     1                         *(gnt(i) - gnt(i-1))
                  if (pair_switch.eq.1)
     1               E_pos = E_pos + n_pos(j,k,i)*gamma(i)
     2                              *(gnt(i) - gnt(i-1))
               endif
 540        continue
            E_el = E_el*ne*8.176d-7*volume
            if (pair_switch.eq.1) E_pos = E_pos*8.176d-7*volume
            E_tot_new = E_tot_new + E_el + E_pos
c
            Delta_T = dabs(Te_new(j,k) - tea(j,k))/Te_new(j,k)
            if (Delta_T.gt.dT_max) dT_max = Delta_T
c 
             write(*, 1005) j, k, Te_new(j,k), tea(j,k)
c______________________________________________________________________
c            Output the new electron distribution
             if ( (j-1).eq.15*int((j-1)/15) .and. 
     1            (k-1).eq.5*int((k-1)/5) .and.
     1           ncycle.gt.0 .and.ncycle.lt.999) then ! Xuhui
             fntname = 'output/fnt_01_01_001.dat'
             fntname(12:12) = char(48 + int(j/10))
             fntname(13:13) = char(48 + j - 10*int(j/10))
             fntname(15:15) = char(48 + int(k/10))
             fntname(16:16) = char(48 + k - 10*int(k/10))
             fntname(18:18) = char(48 + int(ncycle/100))
             fntname(19:19) = char(48 + int(ncycle/10)-
     1                 10*int(ncycle/100))
             fntname(20:20) = char(48 + ncycle-
     1                 10*int(ncycle/10))
             nunit_fnt=22
               open(nunit_fnt, file=fntname, status='unknown')
               do i = 1, num_nt
                 write(nunit_fnt, 55) gnt(i), dmax1(1.d-20,f_new(i)*n_p)
               enddo ! Xuhui
               close(nunit_fnt)
            write(*,*)'electron density',ne
            endif
c            if ((ncycle.eq.2).and.(j.eq.1).and.(k.eq.1)) then
             if ((j.eq.10).and.(k.eq.1)) then ! Xuhui
              open(nunit_fnt, file='output/f_new.dat', status='unknown')
              do i = 1, num_nt
               write(nunit_fnt, 55) gnt(i),dmax1(1.d-20,f_new(i)*ne*n_p)
              enddo ! Xuhui
               close(nunit_fnt)
            endif
c_______________________________________________________________________

c
c
c          Determine approx. parameters of 
c               nonthermal component:
c      gamma_1 = point where curvature of logarithm.
c                distrib. fct. becomes positive;
c           fit spectrum beyond gamma_1 with PL*Exp
c                     (MB, 14/May/1999)
c            curv = 0.
c            curv_old = 0.
c            do 550 i = 5, num_nt-10
c               if (gamma(i).lt.(1. + 3.*Th_e)) goto 550
c               if (f_new(i+1).lt.1.d-10) goto 550
c               if (f_new(i).lt.1.d-10.or.f_new(i-1).lt.1.d-10) 
c     1             goto 550
c               curv_2 = curv_old
c               curv_old = curv
c               curv = dlog(f_new(i+1)/f_new(i))
c     1                /dlog(gnt(i+1)/gnt(i))
c     2              - dlog(f_new(i)/f_new(i-1))
c     3                /dlog(gnt(i)/gnt(i-1))
c               if ((curv.gt.0.).and.(curv_old.gt.0.).and.
c     1             (curv_2.gt.0.)) goto 560
c 550        continue
c 560        continue
c            if (f_new(i).lt.1.d-10) then
c               amxwl(j,k) = 1.d0
c               goto 620
c            endif
c            gmin(j,k) = gamma(i)
c            i_nt = i
c            sum_nt = 0.d0
c            sum_th = 0.d0
c            do 570 i = 1, num_nt-1
c               if (i.lt.i_nt) then
c                  sum_th = sum_th + (gamma(i+1) - gamma(i))*f_new(i)
c               else
c                  sum_nt = sum_nt + (gamma(i+1) - gamma(i))*f_new(i)
c               endif
c  570       continue
c            amxwl(j,k) = sum_th/(sum_nt + sum_th)
c
c            write(4,*) 'gmin = ',gmin(j,k),'; amxwl = ',amxwl(j,k)
c
c            if (amxwl(j,k).gt.9.999d-1) then
c               amxwl(j,k) = 1.d0
c               goto 620
c            endif
c
c
c            if ((i_nt.gt.num_nt-5).or.(f_new(i_nt+5).lt.1.d-20)
c     1          .or.(f_new(i_nt+2).lt.1.d-10)) then
c               amxwl(j,k) = 1.d0
c               goto 620
c            else
c               p_nth(j,k) = dlog(f_new(i_nt+5)/f_new(i_nt+2))
c     1                     /dlog(gamma(i_nt+2)/gamma(i_nt+5))
c            endif
c
c            gmax(j,k) = 1.05d0*gmin(j,k)
c            dg2 = 5.d-2*gmax(j,k)
c            p_1 = 1.d0 - p_nth(j,k)
c            sum_g = 1.d50
c  580       sumg_old = sum_g
c            sum_g = 0.d0
c            if (dabs(p_1).gt.1.d-4) then
c               N_nt = (1. - amxwl(j,k))*p_1
c     1               /(gmax(j,k)**p_1 - gmin(j,k)**p_1)
c            else
c               N_nt = (1.d0 - amxwl(j,k))/log(gmax(j,k)/gmin(j,k))
c            endif
c            do 590 i = i_nt+2, num_nt-2
c              y = gamma(i)/gmax(j,k)
c              if (y.lt.100.d0) then
c                 f_pl = N_nt/((gamma(i)**p_nth(j,k))*exp(y))
c                 if (f_pl.gt.1.d-50)
c     1              sum_g = sum_g + ((f_new(i) - f_pl)**2.d0)/f_pl
c              else
c                 goto 600
c              endif
c  590      continue
c  600      if (sum_g.lt.sumg_old) then
c              if (gmax(j,k).lt.(2.d0*gamma(num_nt))) then
c                 gmax(j,k) = gmax(j,k) + dg2
c              else
c                 goto 610
c              endif
c              goto 580
c
c            endif
c
c 610        continue
c      write(4,*) 'gmax = ',gmax(j,k),'; p_nth = ',p_nth(j,k)
c
c 620        continue
c~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
c            curv = 0.
c            curv_old = 0.
c            do 550 i = 5, num_nt-10
cc               if (gamma(i).lt.(1. + 3.*Th_e)) goto 550 ! Xuhui
c               if (f_new(i+1).lt.1.d-10) goto 550
c               if (f_new(i).lt.1.d-10.or.f_new(i-1).lt.1.d-10) 
c     1             goto 550
c               curv_2 = curv_old
c               curv_old = curv
c               curv = dlog(f_new(i+1)/f_new(i))
c     1                /dlog(gnt(i+1)/gnt(i))
c     2              - dlog(f_new(i)/f_new(i-1))
c     3                /dlog(gnt(i)/gnt(i-1))
c               if ((curv.gt.0.).and.(curv_old.gt.0.).and.
c     1             (curv_2.gt.0.)) goto 560
cc               if(curv.gt.0.) goto 560 ! Xuhui
c 550        continue
c 560        continue
c           if (f_new(i).lt.1.d-10) then
c               amxwl(j,k) = 1.d0
c               goto 620
c            endif
            do 550 i = 5, num_nt-5
 550             if(f_new(i).gt.1.d-10)goto 555
 555        continue
            gmin(j,k) = gamma(i)
            i_nt = i
            do 560 i = num_nt-5,5,-1
 560             if(f_new(i).gt.1.d-15)goto 565
 565        continue
            gmax(j,k)=gamma(i)
            sum_nt = 0.d0
            sum_th = 0.d0
            do 570 i = 1, num_nt-1
               if (i.lt.i_nt) then
                  sum_th = sum_th + (gamma(i+1) - gamma(i))*f_new(i)
               else
                  sum_nt = sum_nt + (gamma(i+1) - gamma(i))*f_new(i)
               endif
  570       continue
            amxwl(j,k) = sum_th/(sum_nt + sum_th)
c
c
            if (amxwl(j,k).gt.9.999d-1) then
               amxwl(j,k) = 1.d0
               goto 620
            endif
c
c
c then
c               amxwl(j,k) = 1.d0
c               goto 620
c            else
c               p_nth(j,k) = dlog(f_new(i_nt+5)/f_new(i_nt+2))
c     1                     /dlog(gamma(i_nt+2)/gamma(i_nt+5))
c            endif 
c
c            gmax(j,k) = 2.d0*gmin(j,k)
c            dg2 = 5.d-2*gmax(j,k)
c            p_1 = 1.d0 - p_nth(j,k)
            p_nth(j,k) = 0.1
            sum_g = 1.d50
  580       sumg_old = sum_g
            sum_g = 0.d0
c            dg2 = 5.d-2*gmax(j,k)
            sum_gg = 0.d0
            p_1 = 1.d0 - p_nth(j,k) 
            if (dabs(p_1).gt.1.d-4) then
               N_nt = (1. - amxwl(j,k))*p_1
     1               /(gmax(j,k)**p_1 - gmin(j,k)**p_1)
            else
               N_nt = (1.d0 - amxwl(j,k))/log(gmax(j,k)/gmin(j,k))
            endif
c            do 590 i = i_nt+2, num_nt-2
            do 590 i = i_nt, num_nt-2
              y = gamma(i)/gmax(j,k)
              if (y.lt.100.d0) then
                 f_pl = N_nt/((gamma(i)**p_nth(j,k))*exp(y))
                 sum_g = sum_g + f_pl*gamma(i)*(gnt(i+1)-gnt(i))
                 sum_gg = sum_gg +f_pl*(gnt(i+1)-gnt(i))
c                 if (f_pl.gt.1.d-50)
c     1              sum_g = sum_g + ((f_new(i) - f_pl)**2.d0)/f_pl

              else
                 goto 600
              endif
  590      continue
  600      continue
           sum_g = sum_g/sum_gg 
           sum_g = abs(sum_g - sum_E)
           if (sum_g.lt.sumg_old) then
c              if (gmax(j,k).lt.(2.d0*gamma(num_nt))) then
c                 gmax(j,k) = gmax(j,k) + dg2
             if(p_nth(j,k).lt.10.)then
               p_nth(j,k) = p_nth(j,k) + 0.5d-1
             else
                 goto 610
             endif
              goto 580
c
           endif
c
 610        continue
c
 620        continue
c~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~! Xuhui fit
            return
            end
c
c
c
c====================================================================================================
c     This performs the first time step.  It lets the simulation
c     volume fill up with photons.
c     J. Finke, 5 May 2005
      subroutine photon_fill
      implicit none
      include 'general.pa'
      include 'commonblock.f'
c
c       Calculate thermal cooling/heating rates
c      and new temperature of thermal population
c                 (MB, 11/May/1999)
c
c     The initial time step lets the simulation volume fill
c     up with photons, then resets the timer to zero.
c
c     variables used only in update2d and its subroutines.
      integer i, j, k, i_ph
      double precision t_fp, n_p
      double precision sum_dt, sum_min, Delta_T
      double precision Th_p, Th_e, g_av, gamma_bar, gamma_R
      double precision h_T, dT_coulp, y, volume, d_t, df_time
      double precision dT_sy, dT_c, dT_br, dT_A, dT_total(jmax,kmax)
      double precision n_positron
      double precision rmid, zmid, tl_flare, tlev, Tp_flare
c
c     variables common from outside update used within update.
c     The Elosses are modified by photon_fill to adjust for the
c     size of the time step.  Te_new is also modified by 
c     photon_fill.
      double precision dg_ic(num_nt)
c
c     d_update has variables that are common between photon_fill, FP_calc, 
c     and update.
c
c     Output formats
  5   format('Evolution of thermal population in zone ',i2,
     1       ',',i2,':')
 10   format ('   Coulomb heating/cooling rate: ',e14.7,' erg/s')
 15   format ('       Synchrotron cooling rate: ',e14.7,' erg/s')
 20   format ('           Compton cooling rate: ',e14.7,' erg/s')
 25   format ('    Bremsstrahlung cooling rate: ',e14.7,' erg/s')
 30   format ('Hydromagnetic acceleration rate: ',e14.7,' erg/s')
 35   format ('     Total heating/cooling rate: ',e14.7,' keV/s')
 45   format('Te_new(',i2,',',i2,') = ',e14.7,' keV')
 50   format(' Adjusted time step: ',e14.7,' s')
c
c
c
      dt_new = dt(1)
      write(4,*) 'Starting thermal evolution calculation.'
c
      do 130 j = 1, nz
         do 129 k = 1, nr
            sum_dt = 0.d0
            Delta_T = 0.d0
            sum_min = -1.d-10
c
            n_p = n_e(j,k)
c            if (n_e(j,k).lt.1.d-2) goto 129
            if (n_e(j,k).lt.1.d-11) goto 129
            if (tna(j,k).lt.1.d0) goto 129
c
            write(4, *)
            write(4,5) j, k
c
c            Th_p = tna(j,k)/5.382d5
c
            if (k.gt.1) then
               rmid = 5.d-1*(r(k) + r(k-1))
            else
               rmid = 5.d-1*(r(k) + rmin)
            endif
            if (j.gt.1) then
               zmid = 5.d-1*(z(j) + z(j-1))
            else
               zmid = 5.d-1*(z(j) + zmin)
            endif
c
            if (cf_sentinel.eq.1) then
               y = 5.d-1*(((rmid - r_flare)/sigma_r)**2.d0
     1                  + ((zmid - z_flare)/sigma_z)**2.d0
     2                  + ((time - t_flare)/sigma_t)**2.d0)
c
               if (y.lt. 1.d2) then
                  tl_flare = flare_amp/dexp(y)
               else
                  tl_flare = 0.d0
               endif
            else
               tl_flare = 0.d0
            endif
            tlev = turb_lev(j,k) + tl_flare
c
            Tp_flare = tna(j,k)*(1.d0 + tl_flare)
            Th_p = Tp_flare/9.382d5
 125        Th_e = tea(j,k)/5.11d2
            g_av = gamma_bar(Th_e)
            gamma_R = 2.1d-3*sqrt(n_e(j,k))/(B_field(j,k)*sqrt(g_av))
c
c             Thermal cooling rates in erg/s
c
            h_T = .79788d0*(2.d0*((Th_e + Th_p)**2.d0) + 2.d0*
     1           (Th_e + Th_p) + 1.d0)/(((Th_e + Th_p)**1.5d0)* 
     2           (1.d0 + 1.875d0*Th_e+ .8203d0*(Th_e**2.d0)))
            dT_coulp = 2.608d-26*n_p*lnL*(Tp_flare - tea(j,k))*h_T
c
            volume = vol(j,k)
c
            y = gamma_R/g_av
            if (y.lt.100.d0) then
c               dT_sy = -6.66667d-1*(Eloss_cy(j,k) + Eloss_sy(j,k) 
c     1            + Eloss_th(j,k))/(volume*n_e(j,k)*dt(1)*dexp(y))
               dT_sy = -6.66667d-1*Eloss_sy(j,k)/
     1                 (volume*n_e(j,k)*dt(1)*dexp(y))
            else
               dT_sy = 0.d0
            endif
c
            n_positron = n_p*f_pair(j,k)
            dT_br = -6.66667d-1*Eloss_br(j,k)/(volume*n_e(j,k)*dt(1))
c
c            dT_c = 6.666667d-1*edep(j,k)/(dt(1)*volume*n_e(j,k))

         dT_c =0.d0
         do i=1,num_nt-1
            dg_ic(i) = 0.d0
            do i_ph = 1, nphfield
                  dg_ic(i) = dg_ic(i) 
     1                     - n_field(i_ph, j, k)*F_IC(i, i_ph)/volume
            enddo
            dT_c = dT_c - 6.666667d-1*8.176d-7*dg_ic(i)*
     1             f_nt(j,k,i)*(gnt(i+1)-gnt(i))
         enddo  ! Xuhui 3/9/11
c
            dT_A = tlev*dT_coulp
c
c           Total thermal heating/cooling rate in keV/s
c
            dT_total(j,k) = (dT_coulp + dT_sy + dT_br + dT_c 
     1                     + dT_A)/1.6d-9
            write(4,10) dT_coulp
            write(4,15) dT_sy
            write(4,20) dT_c
            write(4,25) dT_br
            write(4,30) dT_A
            write(4,35) dT_total(j,k)
            write(4, *)
c
c         Determine optimum time step, d_t, so that
c   electron temperature changes by a factor of df_T.
c
            d_t = df_T*tea(j,k)/dabs(dT_total(j,k))
c            if (d_t.lt.dt_new) dt_new = d_t ! Xuhui 2/17/11
c
  129    continue
  130 continue
c      if(dt_new.gt.dt(1)) dt_new = dt(1)
c
      df_time = dt_new/dt(1)
      do 150 j = 1, nz
         do 149 k = 1, nr
            edep(j,k) = edep(j,k)*df_time
            Eloss_tot(j,k) = Eloss_tot(j,k)*df_time
            Eloss_br(j,k) = Eloss_br(j,k)*df_time
            Eloss_cy(j,k) = Eloss_cy(j,k)*df_time
            Eloss_sy(j,k) = Eloss_sy(j,k)*df_time
            Eloss_th(j,k) = Eloss_th(j,k)*df_time
            Te_new(j,k) = tea(j,k) + dt_new*dT_total(j,k)
            dT_max = df_T
  149   continue
  150 continue       
c     The above loop renormalizes Eloss's to the new time step.
c      time = time - dt(1) + dt_new
c      dt(1) = dt_new ! Xuhui del 5/11/09
      write(4, 50) dt(1)
c
      return
      end
c
c
c
c============================================================================================
c     cens_add_up sums up necessary items from slave nodes:
c     edep, ecens, and n_field.
c     J. Finke, 22 June 2006
      subroutine cens_add_up
      implicit none
      include 'mpif.h'
      include 'general.pa'
      include 'commonblock.f'
c
      integer i, j, k
      double precision E_temp(jmax,kmax), ecens_temp(jmax,kmax), 
     1                 n_temp(nphfield,jmax,kmax)
c
c
      Call MPI_BARRIER(MPI_COMM_WORLD,ierr)
c      do 10 j=1, nz
c         do 20 k=1, nr
c            call MPI_REDUCE(edep(j,k), E_temp, 1, MPI_DOUBLE_PRECISION,
c     1           MPI_SUM, master, MPI_COMM_WORLD, ierr)
c            if(myid.eq.master) edep(j,k) = E_temp
c            call MPI_REDUCE(ecens(j,k), ecens_temp, 1, 
c     1           MPI_DOUBLE_PRECISION, MPI_SUM, master, 
c     2           MPI_COMM_WORLD, ierr)
c            if(myid.eq.master) ecens(j,k) = ecens_temp
c            do 30 i=1,nphfield
c               call MPI_REDUCE(n_field(i,j,k), E_temp, 1,
c     1              MPI_DOUBLE_PRECISION, MPI_SUM, master,
c     2              MPI_COMM_WORLD, ierr)
c               if(myid.eq.master) n_field(i,j,k) = E_temp
c 30         continue
c 20      continue
c 10   continue
       call MPI_REDUCE(edep, E_temp,jmax*kmax,
     1        MPI_DOUBLE_PRECISION, MPI_SUM, master,
     1        MPI_COMM_WORLD, ierr)
       if(myid.eq.master) edep=E_temp

       Call MPI_BARRIER(MPI_COMM_WORLD,ierr)
       call MPI_REDUCE(ecens, ecens_temp,jmax*kmax,
     1        MPI_DOUBLE_PRECISION, MPI_SUM, master,
     1        MPI_COMM_WORLD, ierr)
       if(myid.eq.master) ecens=ecens_temp

       Call MPI_BARRIER(MPI_COMM_WORLD,ierr)
       call MPI_REDUCE(n_field, n_temp,nphfield*jmax*kmax,
     1        MPI_DOUBLE_PRECISION, MPI_SUM, master,
     1        MPI_COMM_WORLD, ierr)
       if(myid.eq.master) n_field=n_temp

      if(myid.eq.master)then
           open(23, file='output/nfield.dat', status='unknown')
           do i=1,nphfield
             write(23, *) E_field(i), dmax1(1.d-20,n_field(i,1,nr))
           enddo
           close(23)
      endif
c
      return
      end
c
c
c
c==================================================================================
c     E_add_up sums the erlk's from the different nodes and
c     zones and puts the sum in E_tot_old.  It also sums
c     the erin's and puts the sum in E_tot_new.
c     J. Finke, 2 May 2005
      subroutine E_add_up
      implicit none
      include 'mpif.h'
      include 'general.pa'
      include 'commonblock.f'
c
c
      integer i
      integer j, k
      double precision E_temp, E_tot_out
      double precision erlku_tot(kmax), erlkl_tot(kmax), 
     1                 erlko_tot(jmax), erlki_tot(jmax)
c
c     d_update has variables that are common between photon_fill, FP_calc, 
c     and update.
c     to_fp_calc has variables common between fp_calc and update
c
c      E_tot_old = 0.d0 
c      E_tot_new = 0.d0
       E_tot_out = 0.d0
c
      call MPI_REDUCE(erlki, erlki_tot, nz, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      call MPI_REDUCE(erlko, erlko_tot, nz, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      call MPI_REDUCE(erlku, erlku_tot, nr, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      call MPI_REDUCE(erlkl, erlkl_tot, nr, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
c
      if(myid.eq.master) then
         write(*,*) 'erini(5)=',erinl(5),' erlkl5=',erlkl_tot(5)
      do 170 j = 1, nz
         E_tot_old = E_tot_old + erini(j) + erino(j)
         E_tot_new = E_tot_new + erlki_tot(j) + erlko_tot(j)
         E_tot_out = E_tot_out + erlki_tot(j) + erlko_tot(j) ! Xuhui Chen 
 170  continue
      do 175 k = 1, nr
         E_tot_old = E_tot_old + erinu(k) + erinl(k)
         E_tot_new = E_tot_new + erlku_tot(k) + erlkl_tot(k)
         E_tot_out = E_tot_out + erlku_tot(k) + erlkl_tot(k) ! Xuhui Chen

 175  continue
      endif
c
      call MPI_REDUCE(dT_max, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_MAX, master, MPI_COMM_WORLD, ierr)
      if(myid.eq.master) dT_max = E_temp
c
      call MPI_REDUCE(E_tot_new, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      if(myid.eq.master) E_tot_new = E_temp
      call MPI_REDUCE(E_tot_old, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)         
      if(myid.eq.master) E_tot_old = E_temp

      do i = 1, num_nt
        call MPI_REDUCE(E_IC(i), E_temp, 1, MPI_DOUBLE_PRECISION,
     1       MPI_SUM, master, MPI_COMM_WORLD, ierr)
        if(myid.eq.master)E_IC(i) = E_temp
      enddo
      if(myid.eq.master)then
           open(23, file='output/eic.dat', status='unknown')
           do i=1,num_nt
             write(23, *) gnt(i), dmax1(1.d-20,E_IC(i))
           enddo
           close(23)
      endif
 
      call MPI_REDUCE(E_tot_out, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      if(myid.eq.master)then
         E_tot_out = E_temp ! Xuhui Chen
         write(4,*)'Luminosity =',E_tot_out/dt(1)
      endif

      call MPI_REDUCE(hr_total, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      if(myid.eq.master) hr_total = E_temp
      call MPI_REDUCE(hr_st_total, E_temp, 1, MPI_DOUBLE_PRECISION,
     1     MPI_SUM, master, MPI_COMM_WORLD, ierr)
      if(myid.eq.master) hr_st_total = E_temp
c
c     end of E_add_up
      return
      end
c
c
c
c
      double precision function Intdgcp(g, b, kTp)
      implicit none
      double precision g, b, kTp
c
      double precision sum, gr, br, gcp, gcm, Om_m
      double precision Om_p, q, s, dgr, sgr, grs
      double precision sd, s0, gs, bs, d, me, mp
      double precision E10, E1s, p10, p1s, xm, xp
      double precision Om1, Om2
c
      sum = 0.
      s0 = 0.
      me = 5.11d2
      mp = 9.38d5
c
      gr = 1.d0
      dgr = 1.001d0
      d = dgr - 1.
      sgr = .5*(1. + dgr)
c
 100  grs = gr*sgr
      br = dsqrt(1. - 1./(grs**2.d0))
      s = mp**2 + me**2.d0 + 2.d0*mp*me*grs
      q = dsqrt(s)/kTp
      gs = (mp*grs + me)/dsqrt(s)
      bs = dsqrt(1.d0 - 1.d0/(gs**2.d0))
      E10 = me*g
      E1s = me*gs
      p10 = me*g*b
      p1s = me*mp*grs*br/dsqrt(s)
      gcp = (E10*E1s + p10*p1s)/(me**2.d0)
      gcm = (E10*E1s - p10*p1s)/(me**2.d0)
      xm = (mp + g*me)/kTp - q*gcm
      xp = (mp + g*me)/kTp - q*gcp
      if (xm.gt.-200.d0) then
         Om1 = dexp(xm)
      else
         Om1 = 0.d0
      endif
      if (xp.gt.-200.d0) then
         Om2 = dexp(xp)
      else
         Om2 = 0.d0
      endif
      Om_p = Om1 + Om2
      Om_m = Om1 - Om2
      sd = (Om_m*(g*((bs*gs)**2.d0) + gs/q) - Om_p*b*g*bs*(gs**2.d0))
     1     /(grs*(br**3.d0))
      sum = sum + sd*gr*d
      gr = gr*dgr
      if (dabs(sd).gt.dabs(s0)) s0 = sd
      if ((dabs(s0).lt.1.d-100).or.(dabs(sd/s0).gt.1.d-8)) goto 100
c
      Intdgcp = sum
      return
      end
c
c
c
c
      double precision function Intd2cp(g, b, kTp)
      implicit none
      double precision g, b, kTp
c
      double precision sum, gr, br, gcp, gcm, eta0
      double precision eta1, eta2, q, s, dgr, sgr
      double precision grs, sd, s0, gs, bs, d, me, lnL
      double precision mp, E10, E1s, p10, p1s, const_A
      double precision const_B, Inteta, tau, p0, p1, p2
c
      sum = 0.
      s0 = 0.
      me = 5.11d2
      mp = 9.38d5
      lnL = 2.d1
c
      gr = 1.d0
      dgr = 1.001d0
      d = dgr - 1.
      sgr = .5*(1. + dgr)
c
 100  grs = gr*sgr
      br = dsqrt(1. - 1./(grs**2.d0))
      const_A = lnL - .25d0*(1.d0 + br**2.d0)
      const_B = lnL - .25d0*(6.d0 + br**2.d0)
      s = mp**2.d0 + me**2.d0 + 2.d0*mp*me*grs
      gs = (mp*grs + me)/dsqrt(s)
      bs = dsqrt(1.d0 - 1.d0/(gs**2.d0))
      E10 = me*g
      E1s = me*gs
      p10 = me*g*b
      p1s = me*mp*grs*br/dsqrt(s)
      gcp = (E10*E1s + p10*p1s)/(me**2.d0)
      gcm = (E10*E1s - p10*p1s)/(me**2.d0)
      q = dsqrt(s)/kTp
      tau = (mp + g*me)/kTp
      p0 = 0.d0
      p1 = 1.d0
      p2 = 2.d0
      eta0 = Inteta(gcm, gcp, p0, q, tau)
      eta1 = Inteta(gcm, gcp, p1, q, tau)
      eta2 = Inteta(gcm, gcp, p2, q, tau)
      sd = (-eta0*(const_A*((bs*gs)**2.d0) + const_B*(g**2.d0)) 
     1     + 2.d0*eta1*const_B*g*gs + eta2*(const_A*((bs*gs)**2.d0) 
     2     - const_B*(gs**2.d0)))/(gs*bs*(br**2.d0))
      sum = sum + sd*gr*d
      gr = gr*dgr
      if (dabs(sd).gt.dabs(s0)) s0 = sd
      if ((dabs(s0).lt.1.d-100).or.(dabs(sd/s0).gt.1.d-8)) goto 100
c
      Intd2cp = sum
      return
      end
c
c
c
c
      double precision function Intdgmo(g, b, Th_e)
      implicit none
      double precision g, b, Th_e
c
      double precision sum, gr, br, gcp, gcm, Om_m
      double precision Om_p, q, dgr, sgr, grs, sd
      double precision s0, gs, bs, d, Y, const_A
      double precision const_B, const_C, lnL, xm, xp
      double precision Om1, Om2
c
      sum = 0.d0
      s0 = 0.d0
      lnL = 2.d1
c
      gr = 1.d0
      dgr = 1.002d0
      if (Th_e.lt.2.d-1) dgr = 1.001d0
      d = dgr - 1.d0
      sgr = 5.d-1*(1.d0 + dgr)
c
 100  grs = gr*sgr
      br = dsqrt(1.d0 - 1.d0/(grs**2.d0))
      q = dsqrt(2.*(grs + 1.d0))/Th_e
      gs = dsqrt(.5d0*(grs + 1.d0))
      bs = dsqrt(1.d0 - 1.d0/(gs**2))
      gcp = g*gs*(1.d0 + b*bs)
      gcm = g*gs*(1.d0 - b*bs)
      xm = (1.d0 + g)/Th_e - q*gcm
      xp = (1.d0 + g)/Th_e - q*gcp
      if (xm.gt.-200.d0) then
         Om1 = dexp(xm)
      else
         Om1 = 0.d0
      endif
      if (xp.gt.-200.d0) then
         Om2 = dexp(xp)
      else
         Om2 = 0.d0
      endif
      Om_p = Om1 + Om2
      Om_m = Om1 - Om2
      const_A = (2.d0*(gs**2.d0) - 1.d0)**2.d0
      const_B = 2.*(gs**4.d0) - gs**2.d0 - .25d0
      const_C = (gs**2.d0 - 1.d0)**2.d0
      Y = 4.98885d-25*(.5d0*const_A*(lnL + 8.465736d-1) 
     1         - 6.9314718d-1*const_B + .125d0*const_C)
     2                /((gs*(gs**2.d0 - 1.d0))**2.d0)
      sd = grs*br*Y*(Om_m*(g*((bs*gs)**2.d0) + gs/q) 
     1             - Om_p*b*g*bs*(gs**2.d0))
      sum = sum + sd*gr*d
      gr = gr*dgr
      if (dabs(sd).gt.dabs(s0)) s0 = sd
      if ((dabs(s0).lt.1.d-100).or.(dabs(sd/s0).gt.1.d-10)) goto 100
c
      Intdgmo = sum
      return
      end
c
c
c
c
      double precision function Intd2mo(g, b, Th_e)
      implicit none
      double precision g, b, Th_e
c
      double precision sum, gr, br, gcp, gcm, I1
      double precision I2, q, dgr, sgr, grs, sd
      double precision s0, gs, bs, d, const_A, p0
      double precision const_B, const_C, lnL, Inteta
      double precision eta0, eta1, eta2, tau, p1, p2
c
      sum = 0.
      s0 = 0.
      lnL = 20.
c
      gr = 1.d0
      dgr = 1.002d0
      if (Th_e.lt.2.d-1) dgr = 1.001d0
      d = dgr - 1.d0
      sgr = 5.d-1*(1. + dgr)
c
 100  grs = gr*sgr
      br = dsqrt(1.d0 - 1.d0/(grs**2.d0))
      q = dsqrt(2.d0*(grs + 1.d0))/Th_e
      gs = dsqrt(.5d0*(grs + 1.d0))
      bs = dsqrt(1.d0 - 1.d0/(gs**2.d0))
      gcp = g*gs*(1.d0 + b*bs)
      gcm = g*gs*(1.d0 - b*bs)
      const_A = (2.d0*(gs**2.d0) - 1.d0)**2.d0
      const_B = 2.d0*(gs**4.d0) - gs**2.d0 - .25d0
      const_C = (gs**2.d0 - 1.d0)**2.d0
c
      I1 = 4.98885d-25*(.5d0*const_A - 3.8629436d-1*const_B 
     1    + 8.3333333d-2*const_C)/((gs*(gs**2.d0 - 1.d0))**2.d0)
      I2 = 4.98885d-25*(const_A*(lnL + .34657d0) - const_B 
     1     + 1.6666667d-1*const_C)/((gs*(gs**2.d0 - 1.d0))**2.d0)
c
c       I1 = 0.d0
c       I2 = 4.98885d-25*const_A*(lnL + .34657)
c     1      /((gs*(gs**2 - 1.))**2)
c
      tau = (1.d0 + g)/Th_e
      p0 = 0.d0
      p1 = 1.d0
      p2 = 2.d0
      eta0 = Inteta(gcm, gcp, p0, q, tau)
      eta1 = Inteta(gcm, gcp, p1, q, tau)
      eta2 = Inteta(gcm, gcp, p2, q, tau)
c
      sd = ((grs**2.d0 - 1.d0)/bs*gs)*(eta0*(I1*(g**2.d0)
     1    - .5d0*I2*(g**2.d0 + (bs*gs)**2.d0)) + 2.d0*eta1*g*gs
     2     *(.5d0*I2 - I1) - eta2*(.5d0*I2 - I1*(gs**2.d0)))
      sum = sum + sd*gr*d
      gr = gr*dgr
      if (dabs(sd).gt.dabs(s0)) s0 = sd
      if ((dabs(s0).lt.1.d-100).or.(dabs(sd/s0).gt.1.d-10)) goto 100
c
      Intd2mo = sum
      return
      end
c
c
c
c
c        Moeller Energie exchange coefficient 
c         neglecting large-angle scatterings:
c              (Nayakshin & Melia 1998)
c
c
      double precision function dg_mo(g, b, Th)
      implicit none
      double precision g, b, Th
c
      double precision sum, sd, x, d, y, chi, gs, bs
      double precision gplus, gminus, ch_f
c
      sum = 0.d0
      x = 1.d0
      d = 1.d-3*Th
c
 100  gs = x + 5.d-1*d
      bs = dsqrt(1.d0 - 1.d0/(gs**2.d0))
      y = gs/Th
      if (y.lt.5.d2) then
         gplus = g*gs*(1.d0 + b*bs)
         gminus = g*gs*(1.d0 - b*bs)
         if (gplus.gt.1.0001d0*gminus) then
            chi = ch_f(gplus) - ch_f(gminus)
            sd = 5.d-1*(gs - g)*chi/dexp(y)
            sum = sum + d*sd
         endif
      endif
      x = x + d
      if (x.lt.(1.d0 + 1.d1*Th)) goto 100
c
      dg_mo = sum
      return
      end
c
c
c
c       Moeller Energie dispersion coefficient 
c         neglecting large-angle scatterings:
c              (Nayakshin & Melia 1998)
c
c
      double precision function disp_mo(g, b, Th)
      implicit none
      double precision g, b, Th
c
      double precision sum, sd, x, d, y, chi, zeta, gs, bs
      double precision gplus, gminus, z_f, ch_f
c
      sum = 0.d0
      x = 1.d0
      d = 1.d-3*Th
c
 100  gs = x + 5.d-1*d
      bs = dsqrt(1.d0 - 1.d0/(gs**2.d0))
      y = gs/Th
      if (y.lt.5.d2) then
         gplus = g*gs*(1.d0 + b*bs)
         gminus = g*gs*(1.d0 - b*bs)
         if (gplus.gt.1.0001d0*gminus) then
            chi = ch_f(gplus) - ch_f(gminus)
            zeta = z_f(g, gs, gplus) - z_f(g, gs, gminus)
            sd = (-5.d-1*((g - gs)**2.d0)*chi + zeta)/dexp(y)
            sum = sum + d*sd
         endif
      endif
      x = x + d
      if (x.lt.(1.d0 + 1.d1*Th)) goto 100
c
      disp_mo = sum
      return
      end
c
c
c
      double precision function ch_f(x)
      implicit none
      double precision x
c
      double precision z, x1, x2, x3, z_f
c
      if (x.lt.1.00000001d0) then
         z_f = 0.d0
         ch_f = 0.d0 ! Xuhui 5/19/09
         goto 100
      endif
      z = dsqrt(5.d-1*(x - 1.d0))
      x1 = 2.d0*dlog(z + dsqrt(z**2.d0 + 1.d0))
      x2 = dsqrt(x**2.d0 - 1.d0)
      x3 = dsqrt((x + 1.d0)/(x - 1.d0))
c
      ch_f = x1 + x2 - x3
 100  return
      end
c
c
c
      double precision function z_f(g, g1, x)
      implicit none
      double precision g, g1, x
c
      double precision z, y, I1, I2
c
      if (x.lt.1.00000001d0) then
         z_f = 0.d0
         goto 100
      endif
      y = x**2.d0 - 1.d0
c
      I1 = dsqrt(y) - dlog(x + dsqrt(y)) + dsqrt((x - 1.d0)/(x + 1.d0))
      I2 = 5.d-1*(x*dsqrt(y) + dlog(x + dsqrt(y)))
c
      z_f = 5.d-1*((g + g1)**2.d0)*I1 - I2
 100  return
      end
c
c
      double precision function Inteta(x0, x1, p, q, tau)
      implicit none
      double precision x0, x1, p, q, tau
c
      double precision x, xs, dx, s, d, sum, sd, y
c
      sum = 0.d0
      x = x0
      d = dmin1((5.d-3*(x1 - x0)/x0), 5.d-3)
      s = 1.d0 + 5.d-1*d
      dx = 1.d0 + d
c
  100 xs = x*s
      y = tau - q*xs
      if (y.gt.-200.d0) then
         if (p.lt.0.1d0) then
           sd = dexp(y)
         else 
           sd = (xs**p)*dexp(y)
         endif
      else
         sd = 0.d0
      endif
      sum = sum + x*d*sd
      x = x*dx
      if ((x*s).lt.x1) goto 100
c
      Inteta = sum
      return
      end
c
c
c
c
c========================================================================================
      subroutine tridag
      implicit none
      include 'general.pa'
c
c
      integer i, n
      double precision bet, gam(num_nt)
      double precision a_i(num_nt), b_i(num_nt), c_i(num_nt),
     1                 f_old(num_nt), f_new(num_nt), 
     2                 npos_old(num_nt), npos_new(num_nt)
      common / trid_update / a_i, b_i, c_i, f_old, f_new, npos_old,
     1                npos_new
c
      if (dabs(b_i(1)).le.1.d-100) then
          write(*,*) 'Error: b(1) = 0.'
         return
      endif
c
      bet = b_i(1)
      f_new(1) = f_old(1)/bet
c
      do 100 i = 2, num_nt 
         gam(i) = c_i(i-1)/bet
         bet = b_i(i) - a_i(i)*gam(i)
         if (dabs(bet).le.1.d-100) then
             write(*,*) 'Error: bet = 0.'
            do 50 n = 1, num_nt
  50        f_new(n) = 0.d0
            return
         endif
c         if(f_old(i).lt.1.d-10)f_old(i)=1.d-10 ! Xuhui
         f_new(i) = (f_old(i) - a_i(i)*f_new(i-1))/bet 
c         if (f_new(i).lt.0.d0) f_new(i) = 0.d0  ! Xuhui
 100  continue
c
      do 200 i = num_nt-1, 1, -1
         f_new(i) = f_new(i) - gam(i+1)*f_new(i+1)
c         if (abs(f_new(i+1)).lt.1.d-8) f_new(i+1) = 0.d0 ! Xuhui
         if (f_new(i+1).lt.0.d0) f_new(i+1) = 0.d0 ! Xuhui
 200  continue
c
      return
      end
c
c
c
c
c============================================================================================
      subroutine trid_p
      implicit none
      include 'general.pa'
c
c
      integer i, n
      double precision bet, gam(num_nt)
      double precision a_i(num_nt), b_i(num_nt), c_i(num_nt),
     1                 f_old(num_nt), f_new(num_nt), 
     2                 npos_new(num_nt), npos_old(num_nt)
      common / trid_update / a_i, b_i, c_i, f_old, f_new, npos_old,
     1                npos_new
c
      if (dabs(b_i(1)).le.1.d-100) then
          write(*,*) 'Error: b(1) = 0.'
         return
      endif
c
      bet = b_i(1)
      npos_new(1) = npos_old(1)/bet
c
      do 100 i = 2, num_nt
         gam(i) = c_i(i-1)/bet
         bet = b_i(i) - a_i(i)*gam(i)    
         if (dabs(bet).le.1.d-100) then
             write(*,*) 'Error: bet = 0.'
            do 50 n = 1, num_nt
  50        npos_new(n) = 0.
            return
         endif
         npos_new(i) = (npos_old(i) - a_i(i)*npos_new(i-1))/bet
 100  continue
c
      do 200 i = num_nt-1, 1, -1
         npos_new(i) = npos_new(i) - gam(i+1)*npos_new(i+1)
         if (npos_new(i).lt.0.d0) npos_new(i) = 0.d0
         if (npos_new(i+1).lt.0.d0) npos_new(i+1) = 0.d0 ! Xuhui
 200  continue
c
      return
      end
c
c
c
cccccccccccccccccccccccccccccccccccccccccccccccccc 
c Tue Jun 13 13:35:43 EDT 2006
c version: 2
c Name: J. Finke
c Added MPI_REDUCE of 'ecens'. Changed various 'write' statements. 
c
cccccccccccccccccccccccccccccccccccccccccccccccccc 
c Thu Jun 22 11:23:38 EDT 2006
c version: 3
c Name: J. Finke
c Added summing of 'n_field' to subroutine 'E_add_up'  
c
cccccccccccccccccccccccccccccccccccccccccccccccccc 
c Wed Jul  5 12:23:31 EDT 2006
c version: 4
c Name: J. Finke
c Create routine cens_add_up, which adds up items related 
c to the census files needed for the FP 
c calculation. It takes the place of E_add_up. E_add_up 
c was moved to after the FP_calculation. E_add_up now 
c also determines the maximum 'dT_max', as well as 
c adding up 'E_tot_new' and 'E_tot_old'.   
