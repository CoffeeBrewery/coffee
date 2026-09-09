# typed: strict
# frozen_string_literal: true

module OS
  module Linux
    module FormulaCellarChecks
      sig { params(filename: ::Pathname).returns(T::Boolean) }
      def valid_library_extension?(filename)
        super || filename.basename.to_s.include?(".so.")
      end

      # A position-independent executable is `ET_DYN` like a shared library and
      # names a dynamic loader as a shared library may, so fall back to how the
      # library is named.
      sig { params(file: ::Pathname).returns(T::Boolean) }
      def binary_program?(file)
        # Cheapest first: the name, then the ELF header, then its program
        # headers, which are parsed rather than read at a fixed offset.
        return false if valid_library_extension?(file)
        return true if super
        return false unless file.is_a?(ELFShim)

        file.dylib? && file.interpreter.present?
      end
    end
  end
end

FormulaCellarChecks.prepend(OS::Linux::FormulaCellarChecks)
