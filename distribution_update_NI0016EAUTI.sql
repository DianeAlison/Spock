--Please run on MHCReporting-P

update s
set EmailAddressesCC = 'LBloebaum@magellanhealth.com; tnheer@magellanhealth.com; goffj@magellanhealth.com; culverhousee@magellanhealth.com'
from ASDUtilityReports..SSISEmailDistributionList s
where reportid in ('NI0016EAUTI Daily PCR Daily');


