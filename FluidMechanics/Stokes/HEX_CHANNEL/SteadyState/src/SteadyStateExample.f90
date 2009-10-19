!> \file
!> $Id: SteadyStateExample.f90 20 2009-04-08 20:22:52Z cpb $
!> \author Sebastian Krittian
!> \brief This is an example program to solve a Stokes equation using openCMISS calls.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> \example FluidMechanics/Stokes/HEX_CHANNEL/SteadyState/src/SteadyStateExample.f90
!! Example program to solve a Stokes equation using openCMISS calls.
!<

!> Main program

PROGRAM StokesFlow

! OpenCMISS Modules

  USE BASE_ROUTINES
  USE BASIS_ROUTINES
  USE BOUNDARY_CONDITIONS_ROUTINES
  USE CMISS
  USE CMISS_MPI
  USE COMP_ENVIRONMENT
  USE CONSTANTS
  USE CONTROL_LOOP_ROUTINES
  USE COORDINATE_ROUTINES
  USE DOMAIN_MAPPINGS
  USE EQUATIONS_ROUTINES
  USE EQUATIONS_SET_CONSTANTS
  USE EQUATIONS_SET_ROUTINES
  USE FIELD_ROUTINES
  USE FIELD_IO_ROUTINES
  USE INPUT_OUTPUT
  USE ISO_VARYING_STRING
  USE KINDS
  USE MESH_ROUTINES
  USE MPI
  USE NODE_ROUTINES
  USE PROBLEM_CONSTANTS
  USE PROBLEM_ROUTINES
  USE REGION_ROUTINES
  USE SOLVER_ROUTINES
  USE TIMER
  USE TYPES

!!!!!
#ifdef WIN32
  USE IFQWIN
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! cmHeart input module
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  USE FLUID_MECHANICS_IO_ROUTINES

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  IMPLICIT NONE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Program types
  TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: BOUNDARY_CONDITIONS
  TYPE(COORDINATE_SYSTEM_TYPE), POINTER :: COORDINATE_SYSTEM
  TYPE(MESH_TYPE), POINTER :: MESH
  TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
  TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
  TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
  TYPE(FIELD_TYPE), POINTER :: GEOMETRIC_FIELD, DEPENDENT_FIELD, MATERIALS_FIELD
  TYPE(PROBLEM_TYPE), POINTER :: PROBLEM
  TYPE(REGION_TYPE), POINTER :: REGION,WORLD_REGION
  TYPE(SOLVER_TYPE), POINTER :: LINEAR_SOLVER
  TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
  TYPE(BASIS_TYPE), POINTER :: BASIS_M,BASIS_V,BASIS_P
  TYPE(MESH_ELEMENTS_TYPE), POINTER :: MESH_ELEMENTS_M,MESH_ELEMENTS_P,MESH_ELEMENTS_V
  TYPE(NODES_TYPE), POINTER :: NODES

  !Program variables
!   INTEGER(INTG) :: NUMBER_OF_DOMAINS 
!   INTEGER(INTG) :: MPI_IERROR
  INTEGER(INTG) :: EQUATIONS_SET_INDEX
  LOGICAL :: EXPORT_FIELD
  TYPE(VARYING_STRING) :: FILE,METHOD
  REAL(SP) :: START_USER_TIME(1),STOP_USER_TIME(1),START_SYSTEM_TIME(1),STOP_SYSTEM_TIME(1)
  INTEGER(INTG) :: NUMBER_COMPUTATIONAL_NODES
  INTEGER(INTG) :: MY_COMPUTATIONAL_NODE_NUMBER
  INTEGER(INTG) :: ERR
  TYPE(VARYING_STRING) :: ERROR
!   INTEGER(INTG) :: DIAG_LEVEL_LIST(5)
!   CHARACTER(LEN=MAXSTRLEN) :: DIAG_ROUTINE_LIST(1),TIMING_ROUTINE_LIST(1)

  !User types
  TYPE(EXPORT_CONTAINER):: CM

  !User variables
  INTEGER(INTG) :: DECOMPOSITION_USER_NUMBER
  INTEGER(INTG) :: GEOMETRIC_FIELD_USER_NUMBER
  INTEGER(INTG) :: REGION_USER_NUMBER
  INTEGER(INTG) :: BC_NUMBER_OF_INLET_NODES,BC_NUMBER_OF_WALL_NODES
  INTEGER(INTG) :: COORDINATE_USER_NUMBER
  INTEGER(INTG) :: MESH_NUMBER_OF_COMPONENTS
  INTEGER(INTG) :: I,J,K
  INTEGER(INTG) :: X_DIRECTION,Y_DIRECTION,Z_DIRECTION
  INTEGER(INTG) :: MAXIMUM_ITERATIONS,RESTART_VALUE
  REAL(DP) :: DIVERGENCE_TOLERANCE, RELATIVE_TOLERANCE, ABSOLUTE_TOLERANCE

  INTEGER, ALLOCATABLE, DIMENSION(:):: BC_INLET_NODES
  INTEGER, ALLOCATABLE, DIMENSION(:):: BC_WALL_NODES
  INTEGER, ALLOCATABLE, DIMENSION(:):: DOF_INDICES
  INTEGER, ALLOCATABLE, DIMENSION(:):: DOF_CONDITION
  REAL(DP),ALLOCATABLE, DIMENSION(:):: DOF_VALUES


#ifdef WIN32
  !Quickwin type
  LOGICAL :: QUICKWIN_STATUS=.FALSE.
  TYPE(WINDOWCONFIG) :: QUICKWIN_WINDOW_CONFIG
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Program starts
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifdef WIN32
  !Initialise QuickWin
  QUICKWIN_WINDOW_CONFIG%TITLE="General Output" !Window title
  QUICKWIN_WINDOW_CONFIG%NUMTEXTROWS=-1 !Max possible number of rows
  QUICKWIN_WINDOW_CONFIG%MODE=QWIN$SCROLLDOWN
  !Set the window parameters
  QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
  !If attempt fails set with system estimated values
  IF(.NOT.QUICKWIN_STATUS) QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
#endif
 
 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Import cmHeart Information
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Read node, element and basis information from cmheart input file
  !Receive CM container for adjusting OpenCMISS calls
  CALL FLUID_MECHANICS_IO_READ_CMHEART(CM,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Intialise cmiss
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(WORLD_REGION)
  CALL CMISS_INITIALISE(WORLD_REGION,ERR,ERROR,*999)

!Set all diganostic levels on for testing
!  DIAG_LEVEL_LIST(1)=1
!  DIAG_LEVEL_LIST(2)=2
!  DIAG_LEVEL_LIST(3)=3
!  DIAG_LEVEL_LIST(4)=4
!  DIAG_LEVEL_LIST(5)=5
!  DIAG_ROUTINE_LIST(1)=""
!  CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"StokesFlowExample",DIAG_ROUTINE_LIST,ERR,ERROR,*999)
!  CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"",DIAG_ROUTINE_LIST,ERR,ERROR,*999)

  !TIMING_ROUTINE_LIST(1)=""
  !CALL TIMING_SET_ON(IN_TIMING_TYPE,.TRUE.,"",TIMING_ROUTINE_LIST,ERR,ERROR,*999)

  !Calculate the start times
  CALL CPU_TIMER(USER_CPU,START_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,START_SYSTEM_TIME,ERR,ERROR,*999)
  !Get the number of computational nodes
  NUMBER_COMPUTATIONAL_NODES=COMPUTATIONAL_NODES_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999
  !Get my computational node number
  MY_COMPUTATIONAL_NODE_NUMBER=COMPUTATIONAL_NODE_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a new RC coordinate system
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(COORDINATE_SYSTEM)
  COORDINATE_USER_NUMBER=1
  CALL COORDINATE_SYSTEM_CREATE_START(COORDINATE_USER_NUMBER,COORDINATE_SYSTEM,ERR,ERROR,*999)
  !Set the coordinate system dimension to CM%D
  CALL COORDINATE_SYSTEM_DIMENSION_SET(COORDINATE_SYSTEM,CM%D,ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_CREATE_FINISH(COORDINATE_SYSTEM,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a region
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(REGION)
  REGION_USER_NUMBER=1
  CALL REGION_CREATE_START(REGION_USER_NUMBER,WORLD_REGION,REGION,ERR,ERROR,*999)
  !Set the regions coordinate system
  CALL REGION_COORDINATE_SYSTEM_SET(REGION,COORDINATE_SYSTEM,ERR,ERROR,*999)
  CALL REGION_CREATE_FINISH(REGION,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a basis for spatial, velocity and pressure field
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(BASIS_M)
  !Spatial basis BASIS_M (CM%ID_M)
  CALL BASIS_CREATE_START(CM%ID_M,BASIS_M,ERR,ERROR,*999)
  !Set Lagrange/Simplex (CM%IT_T) for BASIS_M
  CALL BASIS_TYPE_SET(BASIS_M,CM%IT_T,ERR,ERROR,*999)
  !Set number of XI (CM%D)
  CALL BASIS_NUMBER_OF_XI_SET(BASIS_M,CM%D,ERR,ERROR,*999)
  !Set interpolation (CM%IT_M) for dimensions 
  IF(CM%D==2) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_M,(/CM%IT_M,CM%IT_M/),ERR,ERROR,*999)
  ELSE IF(CM%D==3) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_M,(/CM%IT_M,CM%IT_M,CM%IT_M/),ERR,ERROR,*999)
    CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_M,(/3,3,3/),ERR,ERROR,*999)
  ELSE
    GOTO 999
  END IF
  CALL BASIS_CREATE_FINISH(BASIS_M,ERR,ERROR,*999)

  NULLIFY(BASIS_V)
  !Velocity basis BASIS_V (CM%ID_V)
  CALL BASIS_CREATE_START(CM%ID_V,BASIS_V,ERR,ERROR,*999)
  !Set Lagrange/Simplex (CM%IT_T) for BASIS_V
  CALL BASIS_TYPE_SET(BASIS_V,CM%IT_T,ERR,ERROR,*999)
  !Set number of XI (CM%D)
  CALL BASIS_NUMBER_OF_XI_SET(BASIS_V,CM%D,ERR,ERROR,*999)
  !Set interpolation (CM%IT_V) for dimensions 
  IF(CM%D==2) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_V,(/CM%IT_V,CM%IT_V/),ERR,ERROR,*999)
  ELSE IF(CM%D==3) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_V,(/CM%IT_V,CM%IT_V,CM%IT_V/),ERR,ERROR,*999)
    CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_V,(/3,3,3/),ERR,ERROR,*999)
  ELSE
    GOTO 999
  END IF
  CALL BASIS_CREATE_FINISH(BASIS_V,ERR,ERROR,*999)

  NULLIFY(BASIS_P)
  !Spatial pressure BASIS_P (CM%ID_P)
  CALL BASIS_CREATE_START(CM%ID_P,BASIS_P,ERR,ERROR,*999)
  !Set Lagrange/Simplex (CM%IT_T) for BASIS_P
  CALL BASIS_TYPE_SET(BASIS_P,CM%IT_T,ERR,ERROR,*999)
  !Set number of XI (CM%D)
  CALL BASIS_NUMBER_OF_XI_SET(BASIS_P,CM%D,ERR,ERROR,*999)
  !Set interpolation (CM%IT_P) for dimensions 
  IF(CM%D==2) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_P,(/CM%IT_P,CM%IT_P/),ERR,ERROR,*999)
  ELSE IF(CM%D==3) THEN
    CALL BASIS_INTERPOLATION_XI_SET(BASIS_P,(/CM%IT_P,CM%IT_P,CM%IT_P/),ERR,ERROR,*999)
    CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_P,(/3,3,3/),ERR,ERROR,*999)
  ELSE
    GOTO 999
  END IF
  CALL BASIS_CREATE_FINISH(BASIS_P,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create a mesh with three mesh components for different field interpolations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Define number of mesh components
  MESH_NUMBER_OF_COMPONENTS=3

  NULLIFY(NODES)
  ! Define number of nodes (CM%N_T)
  CALL NODES_CREATE_START(REGION,CM%N_T,NODES,ERR,ERROR,*999)
  CALL NODES_CREATE_FINISH(NODES,ERR,ERROR,*999)

  NULLIFY(MESH)
  ! Define 2D/3D (CM%D) mesh 
  CALL MESH_CREATE_START(1,REGION,CM%D,MESH,ERR,ERROR,*999)
  !Set number of elements (CM%E_T)
  CALL MESH_NUMBER_OF_ELEMENTS_SET(MESH,CM%E_T,ERR,ERROR,*999)
  !Set number of mesh components
  CALL MESH_NUMBER_OF_COMPONENTS_SET(MESH,MESH_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)

  !Specify spatial mesh component (CM%ID_M)
  NULLIFY(MESH_ELEMENTS_M)
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_M,BASIS_M,MESH_ELEMENTS_M,ERR,ERROR,*999)
  !Define mesh topology (MESH_ELEMENTS_M) using all elements' (CM%E_T) associations (CM%M(k,1:CM%EN_M))
  DO k=1,CM%E_T
    CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_M,CM%M(k,1:CM%EN_M),ERR,ERROR,*999)
  END DO
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH_ELEMENTS_M,ERR,ERROR,*999)

  !Specify velocity mesh component (CM%ID_V)
  NULLIFY(MESH_ELEMENTS_V)
  !Velocity:
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_V,BASIS_V,MESH_ELEMENTS_V,ERR,ERROR,*999)
  !Define mesh topology (MESH_ELEMENTS_V) using all elements' (CM%E_T) associations (CM%V(k,1:CM%EN_V))
  DO k=1,CM%E_T
    CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_V,CM%V(k,1:CM%EN_V),ERR,ERROR,*999)
  END DO
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH_ELEMENTS_V,ERR,ERROR,*999)

  !Specify pressure mesh component (CM%ID_P)
  NULLIFY(MESH_ELEMENTS_P)
  !Pressure:
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_P,BASIS_P,MESH_ELEMENTS_P,ERR,ERROR,*999)
  !Define mesh topology (MESH_ELEMENTS_P) using all elements' (CM%E_T) associations (CM%P(k,1:CM%EN_P))
  DO k=1,CM%E_T
    CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_P,CM%P(k,1:CM%EN_P),ERR,ERROR,*999)
  END DO
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH_ELEMENTS_P,ERR,ERROR,*999)
  CALL MESH_CREATE_FINISH(MESH,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create a decomposition for mesh
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(DECOMPOSITION)
  !Define decomposition user number
  DECOMPOSITION_USER_NUMBER=1
  !Perform decomposition
  CALL DECOMPOSITION_CREATE_START(DECOMPOSITION_USER_NUMBER,MESH,DECOMPOSITION,ERR,ERROR,*999)
  !Set the decomposition to be a general decomposition with the specified number of domains
  CALL DECOMPOSITION_TYPE_SET(DECOMPOSITION,DECOMPOSITION_CALCULATED_TYPE,ERR,ERROR,*999)
  CALL DECOMPOSITION_NUMBER_OF_DOMAINS_SET(DECOMPOSITION,NUMBER_COMPUTATIONAL_NODES,ERR,ERROR,*999)
  CALL DECOMPOSITION_CREATE_FINISH(DECOMPOSITION,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define geometric field
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(GEOMETRIC_FIELD)
  !Set X,Y,Z direction parameters
  X_DIRECTION=1
  Y_DIRECTION=2
  Z_DIRECTION=3
  !Set geometric field user number
  GEOMETRIC_FIELD_USER_NUMBER=1

  !Create geometric field
  CALL FIELD_CREATE_START(GEOMETRIC_FIELD_USER_NUMBER,REGION,GEOMETRIC_FIELD,ERR,ERROR,*999)
  !Set field geometric type
  CALL FIELD_TYPE_SET(GEOMETRIC_FIELD,FIELD_GEOMETRIC_TYPE,ERR,ERROR,*999)
  !Set decomposition
  CALL FIELD_MESH_DECOMPOSITION_SET(GEOMETRIC_FIELD,DECOMPOSITION,ERR,ERROR,*999)
  !Disable scaling      
  CALL FIELD_SCALING_TYPE_SET(GEOMETRIC_FIELD,FIELD_NO_SCALING,ERR,ERROR,*999)
  !Set field component to mesh component for each dimension
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,X_DIRECTION,CM%ID_M,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,Y_DIRECTION,CM%ID_M,ERR,ERROR,*999)
  IF(CM%D==3) THEN
    CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,Z_DIRECTION,CM%ID_M,ERR,ERROR,*999)
  ENDIF
  CALL FIELD_CREATE_FINISH(GEOMETRIC_FIELD,ERR,ERROR,*999)

  !Set geometric field parameters (CM%N(k,j)) and do update
  DO k=1,CM%N_M
    DO j=1,CM%D
      CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,CM%ID_M,k,j, &
        & CM%N(k,j),ERR,ERROR,*999)
    END DO
  END DO
  CALL FIELD_PARAMETER_SET_UPDATE_START(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create equations set
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(EQUATIONS_SET)
  !Set the equations set to be a Stokes Flow problem
  CALL EQUATIONS_SET_CREATE_START(1,REGION,GEOMETRIC_FIELD,EQUATIONS_SET,ERR,ERROR,*999)
  CALL EQUATIONS_SET_SPECIFICATION_SET(EQUATIONS_SET,EQUATIONS_SET_FLUID_MECHANICS_CLASS, &
    & EQUATIONS_SET_STOKES_EQUATION_TYPE,EQUATIONS_SET_STATIC_STOKES_SUBTYPE,ERR,ERROR,*999)
  CALL EQUATIONS_SET_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define dependent field and initialise
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the equations set dependent field variables
  NULLIFY(DEPENDENT_FIELD)
  CALL EQUATIONS_SET_DEPENDENT_CREATE_START(EQUATIONS_SET,2,DEPENDENT_FIELD,ERR,ERROR,*999)

  !Set the velocity field component mesh component (default is geometric mesh)
  DO I=1,CM%D
    CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,I,CM%ID_V,ERR,ERROR,*999)
    CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,I,CM%ID_V,ERR,ERROR,*999)
  END DO
  !Set the pressure field component mesh component (default is geometric mesh)
  I=CM%D+1
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,I,CM%ID_P,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,I,CM%ID_P,ERR,ERROR,*999)

  CALL EQUATIONS_SET_DEPENDENT_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)
 
  !Initialise dependent field u=1,v=0,w=0
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
    & FIELD_VALUES_SET_TYPE,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
    & FIELD_VALUES_SET_TYPE,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
    & FIELD_VALUES_SET_TYPE,3,0.0_DP,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define material field and initialise
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the equations set materials field variables
  NULLIFY(MATERIALS_FIELD)
  CALL EQUATIONS_SET_MATERIALS_CREATE_START(EQUATIONS_SET,3,MATERIALS_FIELD,ERR,ERROR,*999)
  CALL EQUATIONS_SET_MATERIALS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)
  
  CALL FIELD_COMPONENT_VALUES_INITIALISE(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
    & FIELD_VALUES_SET_TYPE,1,1.0_DP,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define equations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(EQUATIONS)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
  !Set the equations matrices sparsity type
  CALL EQUATIONS_SPARSITY_TYPE_SET(EQUATIONS,EQUATIONS_SPARSE_MATRICES,ERR,ERROR,*999)
  !CALL EQUATIONS_OUTPUT_TYPE_SET(EQUATIONS,EQUATIONS_ELEMENT_MATRIX_OUTPUT,ERR,ERROR,*999)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define boundary conditions (temporary approach)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  BC_NUMBER_OF_WALL_NODES=1200
  ALLOCATE(BC_WALL_NODES(BC_NUMBER_OF_WALL_NODES))
  BC_WALL_NODES=(/1,2,3,5,6,7,9,10,14,15,16,17,20,23,24,28,30,32,36,37,42,46,48,50,54,55,60,64,65, &
    & 66,67,68,70,72,73,75,77,78,80,82,84,86,90,93,96,124,125,127,130,132,134,136,138,140,144,147,150, &
    & 178,179,181,184,186,188,190,192,194,198,201,204,232,233,235,238,240,242,244,246,248,252,255,258, &
    & 286,287,289,292,294,296,298,300,302,306,309,312,340,341,343,346,348,350,352,354,356,360,363,366, &
    & 394,395,397,400,402,404,406,407,408,409,410,413,414,417,418,419,420,423,424,425,428,431,432,435, & 
    & 436,437,440,443,444,447,448,449,451,452,454,455,456,458,459,460,461,462,464,465,466,467,470,473, &
    & 474,478,480,481,486,490,492,493,498,502,503,504,505,507,509,510,512,514,516,519,522,542,544,546, &
    & 548,550,552,555,558,578,580,582,584,586,588,591,594,614,616,618,620,622,624,627,630,650,652,654, &
    & 656,658,660,663,666,686,688,690,692,694,696,699,702,722,724,726,728,730,731,732,735,736,737,738, & 
    & 741,742,745,746,749,750,753,754,757,758,760,761,762,764,765,766,767,768,770,771,772,773,776,779, &
    & 780,784,786,787,792,796,798,799,804,808,809,810,811,813,815,816,818,820,822,825,828,848,850,852, &
    & 854,856,858,861,864,884,886,888,890,892,894,897,900,920,922,924,926,928,930,933,936,956,958,960, &
    & 962,964,966,969,972,992,994,996,998,1000,1002,1005,1008,1028,1030,1032,1034,1036,1037,1038,1041, &
    & 1042,1043,1044,1047,1048,1051,1052,1055,1056,1059,1060,1063,1064,1066,1067,1068,1070,1071,1072, &
    & 1073,1074,1076,1077,1078,1079,1082,1085,1086,1090,1092,1093,1098,1102,1104,1105,1110,1114,1115, &
    & 1116,1117,1119,1121,1122,1124,1126,1128,1131,1134,1154,1156,1158,1160,1162,1164,1167,1170,1190, &
    & 1192,1194,1196,1198,1200,1203,1206,1226,1228,1230,1232,1234,1236,1239,1242,1262,1264,1266,1268, &
    & 1270,1272,1275,1278,1298,1300,1302,1304,1306,1308,1311,1314,1334,1336,1338,1340,1342,1343,1344, &
    & 1347,1348,1349,1350,1353,1354,1357,1358,1361,1362,1365,1366,1369,1370,1372,1373,1374,1376,1377, &
    & 1378,1379,1380,1382,1383,1384,1385,1388,1391,1392,1396,1398,1399,1404,1408,1410,1411,1416,1420, &
    & 1421,1422,1423,1425,1427,1428,1430,1432,1434,1437,1440,1460,1462,1464,1466,1468,1470,1473,1476, &
    & 1496,1498,1500,1502,1504,1506,1509,1512,1532,1534,1536,1538,1540,1542,1545,1548,1568,1570,1572, &
    & 1574,1576,1578,1581,1584,1604,1606,1608,1610,1612,1614,1617,1620,1640,1642,1644,1646,1648,1649, &
    & 1650,1653,1654,1655,1656,1659,1660,1663,1664,1667,1668,1671,1672,1675,1676,1678,1679,1680,1682, &
    & 1683,1684,1685,1686,1688,1689,1690,1691,1694,1697,1698,1702,1704,1705,1710,1714,1716,1717,1722, &
    & 1726,1727,1728,1729,1731,1733,1734,1736,1738,1740,1743,1746,1766,1768,1770,1772,1774,1776,1779, &
    & 1782,1802,1804,1806,1808,1810,1812,1815,1818,1838,1840,1842,1844,1846,1848,1851,1854,1874,1876, &
    & 1878,1880,1882,1884,1887,1890,1910,1912,1914,1916,1918,1920,1923,1926,1946,1948,1950,1952,1954, &
    & 1955,1956,1959,1960,1961,1962,1965,1966,1969,1970,1973,1974,1977,1978,1981,1982,1984,1985,1986, &
    & 1988,1989,1990,1991,1992,1994,1995,1996,1997,2000,2003,2004,2008,2010,2011,2016,2020,2022,2023, &
    & 2028,2032,2033,2034,2035,2037,2039,2040,2042,2044,2046,2049,2052,2072,2074,2076,2078,2080,2082, &
    & 2085,2088,2108,2110,2112,2114,2116,2118,2121,2124,2144,2146,2148,2150,2152,2154,2157,2160,2180, &
    & 2182,2184,2186,2188,2190,2193,2196,2216,2218,2220,2222,2224,2226,2229,2232,2252,2254,2256,2258, &
    & 2260,2261,2262,2265,2266,2267,2268,2271,2272,2275,2276,2279,2280,2283,2284,2287,2288,2290,2291, &
    & 2292,2294,2295,2296,2297,2298,2300,2301,2302,2303,2306,2309,2310,2314,2316,2317,2322,2326,2328, &
    & 2329,2334,2338,2339,2340,2341,2343,2345,2346,2348,2350,2352,2355,2358,2378,2380,2382,2384,2386, &
    & 2388,2391,2394,2414,2416,2418,2420,2422,2424,2427,2430,2450,2452,2454,2456,2458,2460,2463,2466, &
    & 2486,2488,2490,2492,2494,2496,2499,2502,2522,2524,2526,2528,2530,2532,2535,2538,2558,2560,2562, &
    & 2564,2566,2567,2568,2571,2572,2573,2574,2577,2578,2581,2582,2585,2586,2589,2590,2593,2594,2596, & 
    & 2597,2598,2600,2601,2602,2603,2604,2606,2607,2608,2609,2612,2615,2616,2620,2622,2623,2628,2632, &
    & 2634,2635,2640,2644,2645,2646,2647,2649,2651,2652,2654,2656,2658,2661,2664,2684,2686,2688,2690, &
    & 2692,2694,2697,2700,2720,2722,2724,2726,2728,2730,2733,2736,2756,2758,2760,2762,2764,2766,2769, &
    & 2772,2792,2794,2796,2798,2800,2802,2805,2808,2828,2830,2832,2834,2836,2838,2841,2844,2864,2866, &
    & 2868,2870,2872,2873,2874,2877,2878,2879,2880,2883,2884,2887,2888,2891,2892,2895,2896,2899,2900, &
    & 2902,2903,2904,2906,2907,2908,2909,2910,2912,2913,2914,2915,2918,2921,2922,2926,2928,2929,2934, &
    & 2938,2940,2941,2946,2950,2951,2952,2953,2955,2957,2958,2960,2962,2964,2967,2970,2990,2992,2994, &
    & 2996,2998,3000,3003,3006,3026,3028,3030,3032,3034,3036,3039,3042,3062,3064,3066,3068,3070,3072, &
    & 3075,3078,3098,3100,3102,3104,3106,3108,3111,3114,3134,3136,3138,3140,3142,3144,3147,3150,3170, &
    & 3172,3174,3176,3178,3179,3180,3183,3184,3185,3186,3189,3190,3193,3194,3197,3198,3201,3202,3205, &
    & 3206,3208,3209,3210,3212,3213,3214,3215,3216,3218,3219,3220,3221,3224,3227,3228,3232,3234,3235, &
    & 3240,3244,3246,3247,3252,3256,3257,3258,3259,3261,3263,3264,3266,3268,3270,3273,3276,3296,3298, &
    & 3300,3302,3304,3306,3309,3312,3332,3334,3336,3338,3340,3342,3345,3348,3368,3370,3372,3374,3376, &
    & 3378,3381,3384,3404,3406,3408,3410,3412,3414,3417,3420,3440,3442,3444,3446,3448,3450,3453,3456, &
    & 3476,3478,3480,3482,3484,3485,3486,3489,3490,3491,3492,3495,3496,3499,3500,3503,3504,3507,3508, &
    & 3511,3512,3514,3515,3516,3518,3519,3520,3521,3522,3524,3525,3526,3527,3530,3533,3534,3538,3540, &
    & 3541,3546,3550,3552,3553,3558,3562,3563,3564,3565,3567,3569,3570,3572,3574,3576,3579,3582,3602, & 
    & 3604,3606,3608,3610,3612,3615,3618,3638,3640,3642,3644,3646,3648,3651,3654,3674,3676,3678,3680, &
    & 3682,3684,3687,3690,3710,3712,3714,3716,3718,3720,3723,3726,3746,3748,3750,3752,3754,3756,3759, &
    & 3762,3782,3784,3786,3788,3790,3791,3792,3795,3796,3797,3798,3801,3802,3805,3806,3809,3810,3813, &
    & 3814,3817,3818,3820,3821,3822,3824,3825/)

  BC_NUMBER_OF_INLET_NODES=105
  ALLOCATE(BC_INLET_NODES(BC_NUMBER_OF_INLET_NODES))
  BC_INLET_NODES=(/4,11,12,13,29,33,34,35,47,51,52,53,69,71,83,87,88,89,100,102,103,104,112,114,115, & 
    & 116,126,128,137,141,142,143,154,156,157,158,166,168,169,170,180,182,191,195,196,197,208,210,211, & 
    & 212,220,222,223,224,234,236,245,249,250,251,262,264,265,266,274,276,277,278,288,290,299,303,304, & 
    & 305,316,318,319,320,328,330,331,332,342,344,353,357,358,359,370,372,373,374,382,384,385,386,396, & 
    & 398,411,412,426,427,438,439,450/)

  ALLOCATE(DOF_INDICES(CM%D*(BC_NUMBER_OF_WALL_NODES+BC_NUMBER_OF_INLET_NODES)))
  ALLOCATE(DOF_VALUES(CM%D*(BC_NUMBER_OF_WALL_NODES+BC_NUMBER_OF_INLET_NODES)))
  ALLOCATE(DOF_CONDITION(CM%D*(BC_NUMBER_OF_WALL_NODES+BC_NUMBER_OF_INLET_NODES)))

  DOF_CONDITION=BOUNDARY_CONDITION_FIXED

  DO I=1,CM%D
    DO J=1,BC_NUMBER_OF_WALL_NODES
      DOF_INDICES(J+((I-1)*BC_NUMBER_OF_WALL_NODES))=BC_WALL_NODES(J)+((I-1)*CM%N_V)
      DOF_VALUES(J+((I-1)*BC_NUMBER_OF_WALL_NODES))=0.0_DP
    END DO
  END DO

  DO I=1,CM%D
    DO J=1,BC_NUMBER_OF_INLET_NODES
      DOF_INDICES(CM%D*BC_NUMBER_OF_WALL_NODES+J+((I-1)*BC_NUMBER_OF_INLET_NODES))=BC_INLET_NODES(J)+((I-1)*CM%N_V)
      IF(I==1) THEN !U
        DOF_VALUES(CM%D*BC_NUMBER_OF_WALL_NODES+J+((I-1)*BC_NUMBER_OF_INLET_NODES))=1.0_DP
      ELSE IF(I==2) THEN!V
        DOF_VALUES(CM%D*BC_NUMBER_OF_WALL_NODES+J+((I-1)*BC_NUMBER_OF_INLET_NODES))=0.0_DP
      ELSE !W, I=3
        DOF_VALUES(CM%D*BC_NUMBER_OF_WALL_NODES+J+((I-1)*BC_NUMBER_OF_INLET_NODES))=0.0_DP
      END IF
    END DO
  END DO

  !Create the equations set boundar conditions
  NULLIFY(BOUNDARY_CONDITIONS)
  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_START(EQUATIONS_SET,BOUNDARY_CONDITIONS,ERR,ERROR,*999)
  !Set boundary conditions
  CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,DOF_INDICES,DOF_CONDITION, &
    & DOF_VALUES,ERR,ERROR,*999)
! !    CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,BOUNDARY_CONDITION_FIXED, &
! !      & 0.0_DP,ERR,ERROR,*999)
! !    CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,2,BOUNDARY_CONDITION_FIXED, &
! !      & 0.0_DP,ERR,ERROR,*999)
! !    CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,3,BOUNDARY_CONDITION_FIXED, &
! !      & 1.0_DP,ERR,ERROR,*999)
  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define problem solver settings
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(PROBLEM)
  !Set the problem to be a standard Stokes problem
  CALL PROBLEM_CREATE_START(1,PROBLEM,ERR,ERROR,*999)
    CALL PROBLEM_SPECIFICATION_SET(PROBLEM,PROBLEM_FLUID_MECHANICS_CLASS,PROBLEM_STOKES_EQUATION_TYPE, &
      & PROBLEM_STATIC_STOKES_SUBTYPE,ERR,ERROR,*999)
  CALL PROBLEM_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem control loop
  CALL PROBLEM_CONTROL_LOOP_CREATE_START(PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_CONTROL_LOOP_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Start the creation of the problem solvers
  NULLIFY(LINEAR_SOLVER)
  RELATIVE_TOLERANCE=1.0E-14_DP !default: 1.0E-05_DP
  ABSOLUTE_TOLERANCE=1.0E-14_DP !default: 1.0E-10_DP
  DIVERGENCE_TOLERANCE=1.0E20 !default: 1.0E5
  MAXIMUM_ITERATIONS=100000 !default: 100000
  RESTART_VALUE=300 !default: 30

  CALL PROBLEM_SOLVERS_CREATE_START(PROBLEM,ERR,ERROR,*999)

  !Get linear solver
  CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,LINEAR_SOLVER,ERR,ERROR,*999)
  !Linear solver settings 
!   CALL SOLVER_OUTPUT_TYPE_SET(LINEAR_SOLVER,SOLVER_MATRIX_OUTPUT,ERR,ERROR,*999)
!   CALL SOLVER_OUTPUT_TYPE_SET(LINEAR_SOLVER,SOLVER_PROGRESS_OUTPUT,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_MAXIMUM_ITERATIONS_SET(LINEAR_SOLVER,MAXIMUM_ITERATIONS,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_GMRES_RESTART_SET(LINEAR_SOLVER,RESTART_VALUE,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_DIVERGENCE_TOLERANCE_SET(LINEAR_SOLVER,DIVERGENCE_TOLERANCE,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_ABSOLUTE_TOLERANCE_SET(LINEAR_SOLVER,ABSOLUTE_TOLERANCE,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_RELATIVE_TOLERANCE_SET(LINEAR_SOLVER,RELATIVE_TOLERANCE,ERR,ERROR,*999)
  !For the Direct Solver MUMPS, uncomment the below two lines and comment out the above five
!   CALL SOLVER_LINEAR_TYPE_SET(LINEAR_SOLVER,SOLVER_LINEAR_DIRECT_SOLVE_TYPE,ERR,ERROR,*999)
!   CALL SOLVER_LINEAR_DIRECT_TYPE_SET(LINEAR_SOLVER,SOLVER_DIRECT_MUMPS,ERR,ERROR,*999) 

  !Finish the creation of the problem solvers
  CALL PROBLEM_SOLVERS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define problem equations settings
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the problem solver equations
  NULLIFY(LINEAR_SOLVER)
  NULLIFY(SOLVER_EQUATIONS)
  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_START(PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,LINEAR_SOLVER,ERR,ERROR,*999)
  CALL SOLVER_SOLVER_EQUATIONS_GET(LINEAR_SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
  !Add in the equations set
  CALL SOLVER_EQUATIONS_EQUATIONS_SET_ADD(SOLVER_EQUATIONS,EQUATIONS_SET,EQUATIONS_SET_INDEX,ERR,ERROR,*999)
  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Solve the problem
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Turn of PETSc error handling
  !CALL PETSC_ERRORHANDLING_SET_ON(ERR,ERROR,*999)

  WRITE(*,*)'Solve problem...'
  CALL PROBLEM_SOLVE(PROBLEM,ERR,ERROR,*999) 
  WRITE(*,*)'Problem solved...'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Afterburner
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   FILE="cmgui"
   METHOD="FORTRAN"

   EXPORT_FIELD=.TRUE.
   IF(EXPORT_FIELD) THEN
     WRITE(*,*)'Now export fields...'
     CALL FLUID_MECHANICS_IO_WRITE_CMGUI(REGION,FILE,ERR,ERROR,*999)
     WRITE(*,*)'All fields exported...'
!     CALL FIELD_IO_NODES_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)  
!     CALL FIELD_IO_ELEMENTS_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)
   ENDIF

   !Calculate the stop times and write out the elapsed user and system times
   CALL CPU_TIMER(USER_CPU,STOP_USER_TIME,ERR,ERROR,*999)
   CALL CPU_TIMER(SYSTEM_CPU,STOP_SYSTEM_TIME,ERR,ERROR,*999)

   CALL WRITE_STRING_TWO_VALUE(GENERAL_OUTPUT_TYPE,"User time = ",STOP_USER_TIME(1)-START_USER_TIME(1),", System time = ", &
     & STOP_SYSTEM_TIME(1)-START_SYSTEM_TIME(1),ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Finalise CMISS
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!    CALL CMISS_FINALISE(ERR,ERROR,*999)
   WRITE(*,'(A)') "Program successfully completed."

   STOP
999 CALL CMISS_WRITE_ERROR(ERR,ERROR)
   STOP

END PROGRAM StokesFlow
