def build_header(product_name, product_version):
    """
    Header will look like this
    ***************
    * NAME vVERS. *
    ***************
    """
    header = '{0} v{1}'.format(product_name, product_version)
    delimiter = '*'
    footer_length = len(header) + 4
    footer = delimiter * footer_length
    return footer + '\n' + '{0} {1} {0}'.format(delimiter, header) + '\n' + footer + '\n'

