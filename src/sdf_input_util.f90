MODULE sdf_input_util

  USE mpi
  USE sdf_input
  USE sdf_input_cartesian
  USE sdf_input_point

  IMPLICIT NONE

CONTAINS

  SUBROUTINE sdf_read_blocklist(h)

    TYPE(sdf_file_handle) :: h
    INTEGER :: errcode, buflen, i

    NULLIFY(h%current_block)
    IF (.NOT. h%done_header) CALL sdf_read_header(h)
    IF (ASSOCIATED(h%blocklist)) RETURN

    buflen = h%summary_size
    ALLOCATE(h%buffer(buflen))

    IF (h%rank .EQ. h%rank_master) THEN
      h%current_location = h%summary_location
      CALL MPI_FILE_SEEK(h%filehandle, h%current_location, MPI_SEEK_SET, &
          errcode)

      CALL MPI_FILE_READ(h%filehandle, h%buffer, buflen, &
          MPI_CHARACTER, MPI_STATUS_IGNORE, errcode)
    ENDIF

    CALL MPI_BCAST(h%buffer, buflen, MPI_CHARACTER, h%rank_master, &
        h%comm, errcode)

    h%start_location = h%summary_location
    DO i = 1,h%nblocks
      CALL sdf_read_block_info(h)
    ENDDO

    DEALLOCATE(h%buffer)
    NULLIFY(h%current_block)

  END SUBROUTINE sdf_read_blocklist



  SUBROUTINE sdf_read_block_info(h)

    TYPE(sdf_file_handle) :: h
    TYPE(sdf_block_type), POINTER :: b

    CALL sdf_read_next_block_header(h)
    b => h%current_block

    IF (b%blocktype .EQ. c_blocktype_plain_mesh) THEN
      CALL sdf_read_plain_mesh_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_point_mesh) THEN
      CALL sdf_read_point_mesh_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_plain_variable) THEN
      CALL sdf_read_plain_variable_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_point_variable) THEN
      CALL sdf_read_point_variable_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_constant) THEN
      CALL sdf_read_constant(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_array) THEN
      CALL sdf_read_array_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_cpu_split) THEN
      CALL sdf_read_cpu_split_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_run_info) THEN
      CALL sdf_read_run_info(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_stitched &
        .OR. b%blocktype .EQ. c_blocktype_contiguous &
        .OR. b%blocktype .EQ. c_blocktype_stitched_tensor &
        .OR. b%blocktype .EQ. c_blocktype_contiguous_tensor) THEN
      CALL sdf_read_stitched(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_stitched_material &
        .OR. b%blocktype .EQ. c_blocktype_contiguous_material) THEN
      CALL sdf_read_stitched_material(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_stitched_matvar &
        .OR. b%blocktype .EQ. c_blocktype_contiguous_matvar) THEN
      CALL sdf_read_stitched_matvar(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_stitched_species &
        .OR. b%blocktype .EQ. c_blocktype_contiguous_species) THEN
      CALL sdf_read_stitched_species(h)
    ELSE IF (b%blocktype .EQ. c_blocktype_stitched_obstacle_group) THEN
      CALL sdf_read_stitched_obstacle_group(h)
    ENDIF

  END SUBROUTINE sdf_read_block_info



  SUBROUTINE sdf_read_stitched_info(h, variable_ids)

    TYPE(sdf_file_handle) :: h
    CHARACTER(LEN=*), DIMENSION(:), INTENT(OUT) :: variable_ids
    INTEGER :: iloop
    TYPE(sdf_block_type), POINTER :: b

    IF (.NOT.ASSOCIATED(h%current_block)) THEN
      IF (h%rank .EQ. h%rank_master) THEN
        PRINT*,'*** ERROR ***'
        PRINT*,'SDF block header has not been read. Ignoring call.'
      ENDIF
      RETURN
    ENDIF

    CALL sdf_read_stitched(h)
    b => h%current_block

    DO iloop = 1, b%ndims
      CALL safe_copy_string(b%variable_ids(iloop), variable_ids(iloop))
    ENDDO

  END SUBROUTINE sdf_read_stitched_info

END MODULE sdf_input_util