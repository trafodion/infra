# == Class: traf::users
#
class traf::users {
  $alchen_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEApCL+gIGiEgGh1Dnz8KzHEKyGGWyPdEzOlqkH/dZb+lXmKpnwM72+w5nT5iqPxUbP/rLYkHPlx89f57VkbY4uCzZ72lURYw4yvJAXBGgdHxLY2gh+VnpSiYx7eoILjOZV6lvDKg3CMFdAQcH5Ta7wgoFBCJsZNGq9+RSAZe1hKY0Is2mnxKkowL0CcfJv7y/pYDIteNLzzc99/flhAnZA6PTNQubncsjp2exeLvJ87rkKsmcVJIJzKuWOYGRScPz9ufciH/nKq8vG1zitglhg24952uaJlaf/YdgOjZgtaHOkmYw5US7Ci/EDdqDvXrNq5abUwrkPijppk+tzfDyNhw=='

  $svarnau_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAqYJlJoLhXbUVwbJMew0FlanP5RJ6aBAVNzhOlPgdHCjNeLfDEzMm6dbwO8F1pkB0fSY592ZYYSxu0PZ/8QO0eBCtooZBu4n2WAGCReI8H1VB80Dpsh2YSHk4Fml4dMyWFTvab3ZQwf6r28EE5BvFy9FzI8STNKSUY9PTBZ9H4OSwzapZNxZfjz4G/ovHVWyznZPRZGyTqWXRtHuYmyyw+ub2qv6sy2l3mhQopdI+4YLVll/lmo4LqwDwn3UN8fnwfaw32CqxHYaBtxfJ073uLTWdVE+EITqArsVNqCsDCkvDKA9LlUKul4CFJkzVqrXjBCR/vdqSsyvfs485Qz44sQ=='

  $sandstroms_sshkey = 'AAAAB3NzaC1yc2EAAAABJQAAAQEAiQ0wvM9jt6/8fm+mBQZFtg4mWeD4CylyNrYLhxwPIXwSZXnthpmp1ZKWNRSN2yUe+fTgQ265ArQHJLSmxgz9CRVymNeWrSR8hYiyVWGQo2WzTJkZDrGDlBQtuevJ5Eqg+02Fr6/jaguJc5IMe4CfqbWLgf5Qxyz+IpZ9BaQZIlH7VmzFAJYuQVKAaRMcraQxJiMppskqXZoRdhAECxsnAgjp7imc0AV8qRHW89WbroqRNud+qYtzifXRykDH5jMtHrpb8RYvccrfZuQ8Y5G8eabKlqb6cD30ahsqPMKhCJO94O1J+qc3UtbpuhzR7Onfzrswu24gsZ8Z4iwszH5PfQ=='

  $zellerh_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAxZXs6pbHt+y5TymPLdGccf4LXmSoiliWEFhrrrvJxe2XlGfc++bphcwz/+NB482RE7HltNzd3Fk1M//Ue/NkJA8GgLWOl1qodp86jxMBYbavc2C2qfTUynjQALBF8v5lHdypP19oaqqgQAr1n8mJo0vft1MymoZ72RUgpJMQwRQKW11X3WtFrFzNDCTx6YjKY4EjdelekAKvt0Yc+MCoSa6effrIvKie4wEPbXMjP9G3t1JDN+5xvHNHQoDti4CpQLLonJLW6pSpKiUVjw9CxynJNZHOiGtvKzTojHhJpWyMQBUmDE+R+BKc1bwJ108cmJpWZKdffaWjlpTCnA1Cbw=='

  $wtsai_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAw6VmM81Tr73aqd1oGVyCixiECYap/4HHe7Zra7O626RiPR1T3DeleXVWhivUB+W24/eIgcaaSKuqlwH4yyYvlmXqNgnwjvafLjAqx8hX9z85Vy/o0E3SSgiMKFE2GWyfBJ0ormbW1e5NRCgEC/Ffwo9+DPBoqwTMk/V/UYagN8lZ0zZGK9NFWASyIlp9aqZ64Du7oZVFkQwwLJFrqDGeJuQ73h+CzhkIRP5PNSnPQg5CjHJHGytZTYl1f2JiCVwvuPpf5TthBxljXP6d/Ym7k60/AgECIPqjnKRkOuKCuWOXzwZQqgCa9lyD4V0qvn61fKudZstPjvG5gFTZXxuTIw=='

  $johnstac_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEA1m3jYI3OQ269m+9Qd8/qK1yCeRL5hrihrgFkpnNP1rcZUhBp3cfRYT4acINo0aqoX+Z+sTubWkKFgKEhPVKSE8Wi2XlUhIxXACTBi3/GpJOoiib9Y2bobqCT6o0/OzxQ4Gl4CbieSLhaHeE7BucNIYXbodq9UYM3HGL2Ba8KJA90aKK50TfOgZXEiWlOkdElGCD/XXero2TAdYj0Ehxhlalf8poDWVQ0QhGVt4PxfLrWYf9aDQP6FN3YU/CL0IvqSCY14pJcUHY6gwfKuDKQt3dFt2h6gUJy5eFBwK4NqZuJmc3WdSK2vX9cKibim3Ti1riuC16+bEc6D2vlRtoCmw=='

  $sjohnson_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEA1m3jYI3OQ269m+9Qd8/qK1yCeRL5hrihrgFkpnNP1rcZUhBp3cfRYT4acINo0aqoX+Z+sTubWkKFgKEhPVKSE8Wi2XlUhIxXACTBi3/GpJOoiib9Y2bobqCT6o0/OzxQ4Gl4CbieSLhaHeE7BucNIYXbodq9UYM3HGL2Ba8KJA90aKK50TfOgZXEiWlOkdElGCD/XXero2TAdYj0Ehxhlalf8poDWVQ0QhGVt4PxfLrWYf9aDQP6FN3YU/CL0IvqSCY14pJcUHY6gwfKuDKQt3dFt2h6gUJy5eFBwK4NqZuJmc3WdSK2vX9cKibim3Ti1riuC16+bEc6D2vlRtoCmw=='

  $csheedy_sshkey = 'AAAAB3NzaC1kc3MAAACBALyONTFvWz0PFIfVFMQGTIIVPDKYnNlbRHbnhhwhvWHqsbf97enOjtb41OsYTniKO5ngRz74ezklOgXvDiCosEd8GEbmbJIHPBGr3DVoPKFSOa3QOCZXkpnQ8uALxoGnlSy0nTMT84/PSyYldyBcTF11xsXVG/BerLfIcnaIzly/AAAAFQCAFYPNw9LHgY6dFqrdAXB0pkzcKQAAAIA5cB4inCFT3WfwkV+69Wd5VK0tSiKGBFMGBPt1Ui3yHkGaEHmuImZeQk8GLCBfLBMznigXsNRAl9I3wqOTsIQFNY94d0T5Bifa8/ebW/v8U7WZan5ON3nZPYFqjVNaYFFIbSAKDZvL1ooii3O5xHixubvhlAbYYVVjS0akcC/NGgAAAIA5RGYtJH/OYyN0r6zkm/JRa5lv3hXDQifAZu3pBeOqu/d2Lsv4CvajejsUBMJMceOek0OG41g+gUeSMjXfvPh4tXHYi4NW9fqq8h7YsAX+yroUjZ8/yYLNEB8ApWURP3MzX9enjkwhjBdv3CbrzDq3i9K8t/aIzMY3AbF2fBDVdw=='

  $lowp_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAoBl2WFEuoUh+6uHbgUO04YJ9FvyEs+OYE063NrDL97ob0gM0m4nxAALbi34bslqHaYzHrPBR7Y9bF5vrAAgcduDVvPcqomFzwIA7tOsNGd/wARXi7HsOcyt89BoxulyLRtBjxgpdRSGn9Iq+7AjQdORJXKM0e7LNu9UmGkTS5jGRfkFI3KR6w6qjnsvJnwkza/Kp0ahHMfqnOXGfvbA149/og0t0YplEKAoIzxjrgo6lWs37bB8R1JXtaRIDEQEMftvG1xx+VPR8rjJzUxqPlJa3L6MLaWrPVBlEbRGaAA7BebJ+CTPgr/CVL1eNUlEy0slnx6Xjy2/u3tprsBlqfQ=='

  $anu_sshkey = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAr3/jL5FxiPgyZQT578rj5qXlLvCxDo1tGvTpwkC1HqsAghjtYByHOKMurC1izAwcs2F5ooCNUHLRpoDf4qjJlnNycxFfjdbnn6b+Qlq37hfsr8vQTL+b6heN0/BSYQGnskYL8aPdpngjoonHZ5wFEgyRPA1yIrTL8GvkgYASfSEFkGhBlfjwyA2i5/MYgM0yelkBVZCIGa6VoSn4SUIETZEckAp5w2YthgjNEvmrf141jjAeXc+IF6KSG+Nzw6OAqLc+UkoxC1vBUjFEkDpxggme4vYOnrH5JSoEALrHadQzendxgVurfCPVbts63qj2RNyH3P55YnSO9EpOpL4QoQ=='

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

  @user::virtual::localuser { 'zellerh':
    realname => 'Hans Zeller',
    sshkeys  => "ssh-rsa ${zellerh_sshkey} zellerh\n",
  }

  @user::virtual::localuser { 'wtsai':
    realname => 'Wei-Shiun Tsai',
    sshkeys  => "ssh-rsa ${wtsai_sshkey} wtsai\n",
  }

  @user::virtual::localuser { 'johnstac':
    realname => 'Stacey Johnson',
    sshkeys  => "ssh-rsa ${johnstac_sshkey} johnstac\n",
  }

  @user::virtual::localuser { 'sjohnson':
    realname => 'Stacey Johnson',
    sshkeys  => "ssh-rsa ${sjohnson_sshkey} sjohnson\n",
  }

  @user::virtual::localuser { 'csheedy':
    realname => 'Chris Sheedy',
    sshkeys  => "ssh-dss ${csheedy_sshkey} csheedy\n",
  }

  @user::virtual::localuser { 'lowp':
    realname => 'Paul Low',
    sshkeys  => "ssh-rsa ${lowp_sshkey} lowp\n",
  }

  @user::virtual::localuser { 'hegdean':
    realname => 'Anuradha Hegde',
    sshkeys  => "ssh-rsa ${anu_sshkey} hegdean\n",
  }
}
