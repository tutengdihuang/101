package controllers

import (
	"k8s.io/apimachinery/pkg/api/resource"
)

func resourceQuantity(v string) resource.Quantity {
	q, err := resource.ParseQuantity(v)
	if err != nil {
		return resource.MustParse("0")
	}
	return q
}
