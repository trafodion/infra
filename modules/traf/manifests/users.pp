# == Class: traf::users
#
class traf::users {
  $alchen_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEApCL+gIGiEgGh1Dnz8KzHEKyGGWyPdEzOlqkH/dZb+lXmKpnwM72+w5nT5iqPxUbP/rLYkHPlx89f57VkbY4uCzZ72lURYw4yvJAXBGgdHxLY2gh+VnpSiYx7eoILjOZV6lvDKg3CMFdAQcH5Ta7wgoFBCJsZNGq9+RSAZe1hKY0Is2mnxKkowL0CcfJv7y/pYDIteNLzzc99/flhAnZA6PTNQubncsjp2exeLvJ87rkKsmcVJIJzKuWOYGRScPz9ufciH/nKq8vG1zitglhg24952uaJlaf/YdgOjZgtaHOkmYw5US7Ci/EDdqDvXrNq5abUwrkPijppk+tzfDyNhw=='

  $svarnau_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAqYJlJoLhXbUVwbJMew0FlanP5RJ6aBAVNzhOlPgdHCjNeLfDEzMm6dbwO8F1pkB0fSY592ZYYSxu0PZ/8QO0eBCtooZBu4n2WAGCReI8H1VB80Dpsh2YSHk4Fml4dMyWFTvab3ZQwf6r28EE5BvFy9FzI8STNKSUY9PTBZ9H4OSwzapZNxZfjz4G/ovHVWyznZPRZGyTqWXRtHuYmyyw+ub2qv6sy2l3mhQopdI+4YLVll/lmo4LqwDwn3UN8fnwfaw32CqxHYaBtxfJ073uLTWdVE+EITqArsVNqCsDCkvDKA9LlUKul4CFJkzVqrXjBCR/vdqSsyvfs485Qz44sQ=='

  $sandstroms_sshkey = 'AAAAB3NzaC1yc2EAAAABJQAAAQEAiQ0wvM9jt6/8fm+mBQZFtg4mWeD4CylyNrYLhxwPIXwSZXnthpmp1ZKWNRSN2yUe+fTgQ265ArQHJLSmxgz9CRVymNeWrSR8hYiyVWGQo2WzTJkZDrGDlBQtuevJ5Eqg+02Fr6/jaguJc5IMe4CfqbWLgf5Qxyz+IpZ9BaQZIlH7VmzFAJYuQVKAaRMcraQxJiMppskqXZoRdhAECxsnAgjp7imc0AV8qRHW89WbroqRNud+qYtzifXRykDH5jMtHrpb8RYvccrfZuQ8Y5G8eabKlqb6cD30ahsqPMKhCJO94O1J+qc3UtbpuhzR7Onfzrswu24gsZ8Z4iwszH5PfQ=='

  $csheedy_sshkey = 'AAAAB3NzaC1kc3MAAACBALyONTFvWz0PFIfVFMQGTIIVPDKYnNlbRHbnhhwhvWHqsbf97enOjtb41OsYTniKO5ngRz74ezklOgXvDiCosEd8GEbmbJIHPBGr3DVoPKFSOa3QOCZXkpnQ8uALxoGnlSy0nTMT84/PSyYldyBcTF11xsXVG/BerLfIcnaIzly/AAAAFQCAFYPNw9LHgY6dFqrdAXB0pkzcKQAAAIA5cB4inCFT3WfwkV+69Wd5VK0tSiKGBFMGBPt1Ui3yHkGaEHmuImZeQk8GLCBfLBMznigXsNRAl9I3wqOTsIQFNY94d0T5Bifa8/ebW/v8U7WZan5ON3nZPYFqjVNaYFFIbSAKDZvL1ooii3O5xHixubvhlAbYYVVjS0akcC/NGgAAAIA5RGYtJH/OYyN0r6zkm/JRa5lv3hXDQifAZu3pBeOqu/d2Lsv4CvajejsUBMJMceOek0OG41g+gUeSMjXfvPh4tXHYi4NW9fqq8h7YsAX+yroUjZ8/yYLNEB8ApWURP3MzX9enjkwhjBdv3CbrzDq3i9K8t/aIzMY3AbF2fBDVdw=='



  @user::virtual::localuser { 'svarnau':
    realname => 'Steve Varnau',
    sshkeys  => "ssh-rsa ${svarnau_sshkey} svarnau\n",
  }

  @user::virtual::localuser { 'alchen':
    realname => 'Alice Chen',
    sshkeys  => "ssh-rsa ${alchen_sshkey} alchen\n",
  }

  @user::virtual::localuser { 'sandstroms':
    realname => 'Susan Sandstrom',
    sshkeys  => "ssh-rsa ${sandstroms_sshkey} sandstroms\n",
  }


}
